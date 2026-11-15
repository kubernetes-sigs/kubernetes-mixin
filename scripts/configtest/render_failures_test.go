// Copyright kubernetes-mixin Authors
// SPDX-License-Identifier: Apache-2.0

package configtest

import (
	"encoding/json"
	"fmt"
	"path/filepath"
	"strings"
	"testing"

	"github.com/google/go-jsonnet"
)

const (
	recordingConfig = "additionalGrouping.recordingRules"
	alertingConfig  = "additionalGrouping.alertingRules"

	recordingPreserved = recordingConfig + " contains labels that cannot be preserved in "
	alertingPreserved  = alertingConfig + " contains labels that cannot be preserved in "
	recordingWithout   = recordingConfig + " contains labels removed by without() aggregations in "
	alertingWithout    = alertingConfig + " contains labels removed by without() aggregations in "
	recordingBacked    = alertingConfig + " labels used by recording-backed alerts must also be configured in " + recordingConfig + " for "
)

// fixture describes the part of the mixin a case renders and which grouping lists receive the label.
type fixture struct {
	// imports are repository-relative Jsonnet files that are merged into the mixin.
	imports []string
	// config is extra `_config` Jsonnet source, as a sequence of `field: value,` entries.
	config    string
	recording bool
	alerting  bool
	// output is the mixin field that is rendered: prometheusRules or prometheusAlerts.
	output string
}

// snippet renders the Jsonnet source that applies label to the configured grouping lists.
func (f fixture) snippet(label any, extraConfig string) (string, error) {
	encoded, err := json.Marshal(label)
	if err != nil {
		return "", err
	}
	imports := make([]string, 0, len(f.imports))
	for _, path := range f.imports {
		imports = append(imports, fmt.Sprintf("(import '%s')", path))
	}
	var grouping []string
	if f.recording {
		grouping = append(grouping, fmt.Sprintf("recordingRules: [%s],", encoded))
	}
	if f.alerting {
		grouping = append(grouping, fmt.Sprintf("alertingRules: [%s],", encoded))
	}
	return fmt.Sprintf(`local mixin = %s;
(mixin {
  _config+:: {
    %s
    %s
    additionalGrouping+: { %s },
  },
}).%s
`, strings.Join(imports, " + "), f.config, extraConfig, strings.Join(grouping, " "), f.output), nil
}

const (
	rulesOutput  = "prometheusRules"
	alertsOutput = "prometheusAlerts"
)

// alertSelectors are the selectors the alert modules require, so a module renders on its own.
const alertSelectors = `kubeStateMetricsSelector: 'job="kube-state-metrics"',
    kubeletSelector: 'job="kubelet"',
    kubeApiserverSelector: 'job="kube-apiserver"',
    nodeExporterSelector: 'job="node-exporter"',
    kubeJobTimeoutDuration: '10800',`

// noAPIWindows disables the API server SLOs, so KubeAPIErrorBudgetBurn is not rendered.
const noAPIWindows = "SLOs+: { apiserver+: { windows: [] } },"

var (
	// The full mixin only reports errors that name no module, because several modules can reject
	// the same label and which one reports first depends on evaluation order.
	fullRecording = fixture{imports: []string{"mixin.libsonnet"}, recording: true, output: rulesOutput}
	fullAlerting  = fixture{imports: []string{"mixin.libsonnet"}, alerting: true, output: alertsOutput}

	// Every other fixture renders one module in isolation, so a conflict in another module
	// cannot satisfy or mask the expected error.
	appsRules      = isolatedRules("rules/apps.libsonnet")
	nodeRules      = isolatedRules("rules/node.libsonnet")
	kubeletRules   = isolatedRules("rules/kubelet.libsonnet")
	windowsRules   = isolatedRules("rules/windows.libsonnet")
	schedulerRules = isolatedRules("rules/kube_scheduler.libsonnet")

	apiserverAvailabilityRules = fixture{
		imports:   []string{"config.libsonnet", "rules/kube_apiserver-config.libsonnet", "rules/kube_apiserver-availability.libsonnet"},
		recording: true,
		output:    rulesOutput,
	}

	appsAlerts     = isolatedAlerts("alerts/apps_alerts.libsonnet")
	apiserverAlert = isolatedAlerts("alerts/kube_apiserver.libsonnet")
	kubeletAlerts  = isolatedAlerts("alerts/kubelet.libsonnet")
	resourceAlerts = isolatedAlerts("alerts/resource_alerts.libsonnet")
	storageAlerts  = isolatedAlerts("alerts/storage_alerts.libsonnet")
	systemAlerts   = isolatedAlerts("alerts/system_alerts.libsonnet")
)

func isolatedRules(module string) fixture {
	return fixture{
		imports:   []string{"config.libsonnet", module},
		recording: true,
		output:    rulesOutput,
	}
}

// isolatedAlerts adds the label to both lists. Use alertingOnly to leave the recording rules
// without it.
func isolatedAlerts(module string) fixture {
	return fixture{
		imports:   []string{"config.libsonnet", module},
		config:    alertSelectors,
		recording: true,
		alerting:  true,
		output:    alertsOutput,
	}
}

func (f fixture) alertingOnly() fixture {
	f.recording = false
	return f
}

func (f fixture) withConfig(config string) fixture {
	f.config += "\n    " + config
	return f
}

type testCase struct {
	fixtureName string
	fixture     fixture
	label       any
	// config is extra `_config` Jsonnet source for this case only.
	config string
	// want is a substring of the expected error.
	want string
}

func (tc testCase) name() string {
	switch label := tc.label.(type) {
	case string:
		if label == "" {
			return tc.fixtureName + "/empty"
		}
		return tc.fixtureName + "/" + label
	default:
		return fmt.Sprintf("%s/%T-%v", tc.fixtureName, label, label)
	}
}

func cases() []testCase {
	var cases []testCase
	add := func(name string, f fixture, label any, want string) {
		cases = append(cases, testCase{fixtureName: name, fixture: f, label: label, want: want})
	}

	// Labels removed by a `without()` aggregation can never reach the result.
	add("nodeRules", nodeRules, "mode", recordingWithout+"node recording rules: mode")
	add("schedulerRules", schedulerRules, "instance", recordingWithout+"kube-scheduler recording rules: instance")
	add("schedulerRules", schedulerRules, "pod", recordingWithout+"kube-scheduler recording rules: pod")
	cases = append(cases, testCase{
		fixtureName: "schedulerRulesCustomPodLabel",
		fixture:     schedulerRules,
		label:       "scheduler_pod",
		config:      "podLabel: 'scheduler_pod',",
		want:        recordingWithout + "kube-scheduler recording rules: scheduler_pod",
	})
	add("resourceAlerts", resourceAlerts, "job", alertingWithout+"kubernetes-resources alerting rules: job")
	add("apiserverAlerts", apiserverAlert, "service", alertingWithout+"kube-apiserver alerting rules: service")

	// Alerts that read recording rules need the label in the recording rules as well.
	add("apiserverAlertsAlertingOnly", apiserverAlert.alertingOnly(), "tenant", recordingBacked+"KubeAPIErrorBudgetBurn: tenant")
	add("kubeletAlertsAlertingOnly", kubeletAlerts.alertingOnly(), "tenant", recordingBacked+"KubeletPlegDurationHigh: tenant")
	add("apiserverAlertsNoWindowsAlertingOnly", apiserverAlert.alertingOnly().withConfig(noAPIWindows), "tenant", recordingBacked+"KubeAPIErrorBudgetBurn: tenant")
	add("resourceAlertsAlertingOnly", resourceAlerts.alertingOnly(), "tenant", recordingBacked+"KubeCPUOvercommit and KubeMemoryOvercommit: tenant")
	add("resourceAlertsMultiClusterAlertingOnly", resourceAlerts.alertingOnly().withConfig("showMultiCluster: true,"), "tenant", recordingBacked+"KubeCPUOvercommit and KubeMemoryOvercommit: tenant")

	// Labels that a recording rule consumes or overwrites cannot be preserved.
	add("appsRules", appsRules, "workload_type", recordingPreserved+"application recording rules: workload_type")
	add("appsRules", appsRules, "workload", recordingPreserved+"application recording rules: workload")
	add("appsRules", appsRules, "replicaset", recordingPreserved+"application recording rules: replicaset")
	add("appsRules", appsRules, "job_name", recordingPreserved+"application recording rules: job_name")
	add("apiserverAvailabilityRules", apiserverAvailabilityRules, "verb", recordingPreserved+"kube-apiserver availability recording rules: verb")
	add("nodeRules", nodeRules, "cpu", recordingPreserved+"node recording rules: cpu")
	add("kubeletRules", kubeletRules, "le", recordingPreserved+"kubelet recording rules: le")
	add("windowsRules", windowsRules, "core", recordingPreserved+"Windows recording rules: core")
	add("windowsRules", windowsRules, "container_id", recordingPreserved+"Windows recording rules: container_id")

	// Scrape-target identity labels differ between the exporters that rules join.
	for _, label := range []string{"endpoint", "instance", "job", "service"} {
		add("appsRules", appsRules, label, recordingPreserved+"application recording rules: "+label)
		add("nodeRules", nodeRules, label, recordingPreserved+"node recording rules: "+label)
		add("windowsRules", windowsRules, label, recordingPreserved+"Windows recording rules: "+label)
	}

	// Labels that an alert query consumes or overwrites cannot be preserved.
	add("appsAlerts", appsAlerts, "severity", alertingPreserved+"application alerting rules: severity")
	add("appsAlerts", appsAlerts, "phase", alertingPreserved+"application alerting rules: phase")
	add("appsAlerts", appsAlerts, "revision", alertingPreserved+"application alerting rules: revision")
	add("storageAlerts", storageAlerts, "access_mode", alertingPreserved+"storage alerting rules: access_mode")
	add("systemAlerts", systemAlerts, "git_version", alertingPreserved+"system alerting rules: git_version")
	add("apiserverAlerts", apiserverAlert, "le", alertingPreserved+"kube-apiserver alerting rules: le")
	add("kubeletAlerts", kubeletAlerts, "node", alertingPreserved+"kubelet alerting rules: node")
	// The overcommit and burn-rate checks do not depend on showMultiCluster or the SLO windows.
	add("resourceAlerts", resourceAlerts, "pod", alertingPreserved+"kubernetes-resources alerting rules: pod")
	add("resourceAlertsMultiCluster", resourceAlerts.withConfig("showMultiCluster: true,"), "pod", alertingPreserved+"kubernetes-resources alerting rules: pod")
	add("apiserverAlertsNoWindows", apiserverAlert.withConfig(noAPIWindows), "long", alertingPreserved+"kube-apiserver alerting rules: long")

	// Configured values have to be valid Prometheus label names.
	for _, label := range []string{"tenant-id", "", "9tenant"} {
		add("fullRecording", fullRecording, label, recordingConfig+" contains an invalid Prometheus label name:")
		add("fullAlerting", fullAlerting, label, alertingConfig+" contains an invalid Prometheus label name:")
	}
	add("fullRecording", fullRecording, 1, recordingConfig+" must contain only Prometheus label name strings, got number")
	add("fullAlerting", fullAlerting, 1, alertingConfig+" must contain only Prometheus label name strings, got number")

	return cases
}

func TestRenderFailures(t *testing.T) {
	root, err := filepath.Abs(filepath.Join("..", ".."))
	if err != nil {
		t.Fatal(err)
	}

	all := cases()
	if len(all) != 50 {
		t.Fatalf("expected 50 cases, got %d; update this count together with the table", len(all))
	}
	seen := map[string]bool{}
	for _, tc := range all {
		if seen[tc.name()] {
			t.Fatalf("duplicate case name %q", tc.name())
		}
		seen[tc.name()] = true
	}

	for _, tc := range all {
		t.Run(tc.name(), func(t *testing.T) {
			t.Parallel()

			snippet, err := tc.fixture.snippet(tc.label, tc.config)
			if err != nil {
				t.Fatal(err)
			}
			vm := jsonnet.MakeVM()
			// The repository root serves the snippet's imports; vendor serves the mixin's dependencies.
			vm.Importer(&jsonnet.FileImporter{JPaths: []string{root, filepath.Join(root, "vendor")}})
			_, err = vm.EvaluateAnonymousSnippet("render-failure.jsonnet", snippet)
			if err == nil {
				t.Fatalf("expected rendering to fail with %q\nsnippet:\n%s", tc.want, snippet)
			}
			if !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("expected error containing %q, got:\n%s", tc.want, err)
			}
		})
	}
}
