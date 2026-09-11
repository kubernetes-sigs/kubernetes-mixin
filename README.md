<!-- Copyright kubernetes-mixin Authors
SPDX-License-Identifier: Apache-2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. -->

# Prometheus Monitoring Mixin for Kubernetes

[![ci](https://github.com/kubernetes-sigs/kubernetes-mixin/actions/workflows/ci.yaml/badge.svg)](https://github.com/kubernetes-sigs/kubernetes-mixin/actions/workflows/ci.yaml)

A set of Grafana dashboards and Prometheus alerts for Kubernetes.

This repository was transferred from [`kubernetes-monitoring/kubernetes-mixin`](https://github.com/kubernetes-monitoring/kubernetes-mixin) to [`kubernetes-sigs/kubernetes-mixin`](https://github.com/kubernetes-sigs/kubernetes-mixin). Please reference `github.com/kubernetes-sigs/kubernetes-mixin` in your mixins going forward. Existing references to `github.com/kubernetes-monitoring/kubernetes-mixin` continue to work via GitHub's transfer redirects.

## Local development

Run the following command to setup a local [kind](https://kind.sigs.k8s.io) cluster:

```shell
make dev
```

You should see the following output if successful:

```shell
╔═══════════════════════════════════════════════════════════════╗
║             🚀 Development Environment Ready! 🚀              ║
║                                                               ║
║   Run `make dev-port-forward`                                 ║
║   Grafana will be available at http://localhost:3000          ║
║                                                               ║
║   Data will be available in a few minutes.                    ║
║                                                               ║
║   Dashboards will refresh every 10s, run `make generate`      ║
║   and refresh your browser to see the changes.                ║
║                                                               ║
║   Alert and recording rules require `make dev-reload`.        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

To delete the cluster, run the following:

```shell
make dev-down
```

## Releases

> Note: Releases up until `release-0.12` are changes in their own branches. Changelogs are included in releases starting from [version-0.13.0](https://github.com/kubernetes-sigs/kubernetes-mixin/releases/tag/version-0.13.0).

| Release branch | Kubernetes Compatibility | Prometheus Compatibility | Kube-state-metrics Compatibility |
|----------------|--------------------------|--------------------------|----------------------------------|
| release-0.1    | v1.13 and before         |                          |                                  |
| release-0.2    | v1.14.1 and before       | v2.11.0+                 |                                  |
| release-0.3    | v1.17 and before         | v2.11.0+                 |                                  |
| release-0.4    | v1.18                    | v2.11.0+                 |                                  |
| release-0.5    | v1.19                    | v2.11.0+                 |                                  |
| release-0.6    | v1.19+                   | v2.11.0+                 |                                  |
| release-0.7    | v1.19+                   | v2.11.0+                 | v1.x                             |
| release-0.8    | v1.20+                   | v2.11.0+                 | v2.0+                            |
| release-0.9    | v1.20+                   | v2.11.0+                 | v2.0+                            |
| release-0.10   | v1.20+                   | v2.11.0+                 | v2.0+                            |
| release-0.11   | v1.23+                   | v2.11.0+                 | v2.0+                            |
| release-0.12   | v1.23+                   | v2.11.0+                 | v2.0+                            |
| release-0.13   | v1.23+                   | v2.11.0+                 | v2.0+                            |
| master         | v1.26+                   | v2.11.0+                 | v2.0+                            |

In Kubernetes 1.14 there was a major [metrics overhaul](https://github.com/kubernetes/enhancements/issues/1206) implemented. Therefore v0.1.x of this repository is the last release to support Kubernetes 1.13 and previous version on a best effort basis.

Some alerts now use Prometheus filters made available in Prometheus 2.11.0, which makes this version of Prometheus a dependency.

Warning: This compatibility matrix was initially created based on experience, we do not guarantee the compatibility, it may be updated based on new learnings.

Warning: By default the expressions will generate *grafana 7.2+* compatible rules using the *$\_\_rate_interval* variable for rate functions. If you need backward compatible rules please set *grafana72: false* in your *\_config*

### Release steps

Maintainers can trigger the [release workflow](.github/workflows/release.yaml) by pushing a git tag that matches the pattern: `version-*`.

1. Checkout `master` branch and pull for latest.

   ```bash
   git checkout master
   ```

2. Create a tag following sem-ver versioning for the version and trigger release.

   ```bash
   # replace MAJOR.MINOR.PATCH with e.g. 1.2.3
   tag=version-MAJOR.MINOR.PATCH; git tag $tag && git push origin $tag
   ```

#### Decisions on backfilling releases

We wanted to backfill `release-0.1` to `release-0.12` to have a changelog, but we were not able to use a GitHub action in a newer commit to trigger a release that generates a changelog on older commits. See #489 for full discussion.

## Metrics Deprecation

The following recording rule is marked deprecated. It will be removed in v2.0.0.

```bash
node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate
```

It will be replaced by the following recording rule to preserve data points using `rate` and add `5m` to indicate the range of the rate query in the recording rule name.

```bash
node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m
```

## How to use

This mixin is designed to be vendored into the repo with your infrastructure config. To do this, use [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

You then have three options for deploying your dashboards

1. Generate the config files and deploy them yourself
2. Use ksonnet to deploy this mixin along with Prometheus and Grafana
3. Use prometheus-operator to deploy this mixin (TODO)

## Generate config files

You can manually generate the alerts, dashboards and rules files, but first you must install some tools:

```
$ go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
$ brew install jsonnet
```

Then, grab the mixin, its dependencies, and build:

```
$ git clone https://github.com/kubernetes-sigs/kubernetes-mixin
$ cd kubernetes-mixin
$ make generate
```

The `prometheus_alerts.yaml` and `prometheus_rules.yaml` files then need to passed to your Prometheus server, and the files in `dashboards_out` need to be imported into you Grafana server. The exact details will depending on how you deploy your monitoring stack to Kubernetes.

### Dashboards for Windows Nodes

There exist separate dashboards for windows resources.

1. Compute Resources / Cluster(Windows)
2. Compute Resources / Namespace(Windows)
3. Compute Resources / Pod(Windows)
4. USE Method / Cluster(Windows)
5. USE Method / Node(Windows)

These dashboards are based on metrics populated by [windows-exporter](https://github.com/prometheus-community/windows_exporter) from each Windows node.

## Running the tests

```sh
make test
```

## Using with prometheus-ksonnet

Alternatively you can also use the mixin with [prometheus-ksonnet](https://github.com/kausalco/public/tree/master/prometheus-ksonnet), a [ksonnet](https://github.com/ksonnet/ksonnet) module to deploy a fully-fledged Prometheus-based monitoring system for Kubernetes:

Make sure you have the ksonnet v0.8.0:

```
$ brew install https://raw.githubusercontent.com/ksonnet/homebrew-tap/82ef24cb7b454d1857db40e38671426c18cd8820/ks.rb
$ brew pin ks
$ ks version
ksonnet version: v0.8.0
jsonnet version: v0.9.5
client-go version: v1.6.8-beta.0+$Format:%h$
```

In your config repo, if you don't have a ksonnet application, make a new one (will copy credentials from current context):

```
$ ks init <application name>
$ cd <application name>
$ ks env add default
```

Grab the kubernetes-jsonnet module using and its dependencies, which include the kubernetes-mixin:

```
$ go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
$ jb init
$ jb install github.com/kausalco/public/prometheus-ksonnet
```

Assuming you want to run in the default namespace ('environment' in ksonnet parlance), add the follow to the file `environments/default/main.jsonnet`:

```jsonnet
local prometheus = import "prometheus-ksonnet/prometheus-ksonnet.libsonnet";

prometheus {
  _config+:: {
    namespace: "default",
  },
}
```

Apply your config:

```
$ ks apply default
```

## Using prometheus-operator

TODO

## Multi-cluster support

Kubernetes-mixin can support dashboards across multiple clusters. You need either a multi-cluster [Thanos](https://github.com/improbable-eng/thanos) installation with `external_labels` configured or a [Cortex](https://github.com/cortexproject/cortex) system where a cluster label exists. To enable this feature you need to configure the following:

```jsonnet
    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: true,
    clusterLabel: '<your cluster label>',
```

## Customising the mixin

Kubernetes-mixin allows you to override the selectors used for various jobs, to match those used in your Prometheus set. You can also customize the dashboard names and add grafana tags.

In a new directory, add a file `mixin.libsonnet`:

```jsonnet
local kubernetes = import "kubernetes-mixin/mixin.libsonnet";

kubernetes {
  _config+:: {
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    cadvisorSelector: 'job="kubernetes-cadvisor"',
    nodeExporterSelector: 'job="kubernetes-node-exporter"',
    kubeletSelector: 'job="kubernetes-kubelet"',
    grafanaK8s+:: {
      dashboardNamePrefix: 'Mixin / ',
      dashboardTags: ['kubernetes', 'infrastucture'],
    },
  },
}
```

Then, install the kubernetes-mixin:

```
$ jb init
$ jb install github.com/kubernetes-sigs/kubernetes-mixin
```

Generate the alerts, rules and dashboards:

```
$ jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusAlerts)' > alerts.yml
$ jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusRules)' >files/rules.yml
$ jsonnet -J vendor -m files/dashboards -e '(import "mixin.libsonnet").grafanaDashboards'
```

### Customising alert annotations

The steps described below extend on the existing mixin library without modifying the original git repository. This is to make consuming updates to your extended alert definitions easier. These definitions can reside outside of this repository and added to your own custom location, where you can define your alert dependencies in your `jsonnetfile.json` and add customisations to the existing definitions.

In your working directory, create a new file `kubernetes_mixin_override.libsonnet` with the following:

```jsonnet
local utils = import 'lib/utils.libsonnet';
(import 'mixin.libsonnet') +
(
  {
    prometheusAlerts+::
      // The specialAlerts can be in any other config file
      local slack = 'observability';
      local specialAlerts = {
        KubePodCrashLooping: { slack_channel: slack },
        KubePodNotReady: { slack_channel: slack },
      };

      local addExtraAnnotations(rule) = rule {
        [if 'alert' in rule then 'annotations']+: {
          dashboard: 'https://foo.bar.co',
          [if rule.alert in specialAlerts then 'slack_channel']: specialAlerts[rule.alert].slack_channel,
        },
      };
      utils.mapRuleGroups(addExtraAnnotations),
  }
)
```

Create new file: `lib/kubernetes_customised_alerts.jsonnet` with the following:

```jsonnet
std.manifestYamlDoc((import '../kubernetes_mixin_override.libsonnet').prometheusAlerts)
```

Running `jsonnet -S lib/kubernetes_customised_alerts.jsonnet` will build the alerts with your customisations.

Same result can be achieved by modyfying the existing `config.libsonnet` with the content of `kubernetes_mixin_override.libsonnet`.

## Background

### Alert Severities

While the community has not yet fully agreed on alert severities and their to be used, this repository assumes the following paradigms when setting the severities:

- Critical: An issue, that needs to page a person to take instant action
- Warning: An issue, that needs to be worked on but in the regular work queue or for during office hours rather than paging the oncall
- Info: Is meant to support a trouble shooting process by informing about a non-normal situation for one or more systems but not worth a page or ticket on its own.

### Architecture and Technical Decisions

- For more motivation, see "[The RED Method: How to instrument your services](https://kccncna17.sched.com/event/CU8K/the-red-method-how-to-instrument-your-services-b-tom-wilkie-kausal?iframe=no&w=100%&sidebar=yes&bg=no)" talk from CloudNativeCon Austin.
- For more information about monitoring mixins, see this [design doc](DESIGN.md).

## Note

You can use the external tool call [prom-metrics-check](https://github.com/ContainerSolutions/prom-metrics-check) to validate the created dashboards. This tool allows you to check if the metrics installed and used in Grafana dashboards exist in the Prometheus instance. Please have a look at https://github.com/ContainerSolutions/prom-metrics-check.
