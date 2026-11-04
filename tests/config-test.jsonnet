// Copyright kubernetes-mixin Authors
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Generation-level regression tests for configurations the mixin has to keep supporting.
// Evaluated by `make config-test`, where a failed assertion fails the build.

local utils = import '../lib/utils.libsonnet';
local mixin = import '../mixin.libsonnet';

local withApiserverWindows(windows) = mixin {
  _config+:: {
    SLOs+: {
      apiserver+: {
        windows: windows,
      },
    },
  },
};

local groupRules(groups, name) =
  local matching = [group.rules for group in groups if group.name == name];
  if std.length(matching) == 0 then error 'no group named %s' % name else matching[0];

local recordNames(rules) = std.set([rule.record for rule in rules]);

local averagedRecords(rules) = std.set([
  rule.record
  for rule in rules
  if std.length(std.findSubstr('avg_over_time', rule.expr)) > 0
]);

local findRules(groups, record) =
  [rule for group in groups for rule in group.rules if rule.record == record];

local findRule(groups, record) =
  local matching = findRules(groups, record);
  if std.length(matching) == 0 then error 'no rule recording %s' % record else matching[0];

local findAlerts(groups, alert) =
  [rule for group in groups for rule in group.rules if std.objectHas(rule, 'alert') && rule.alert == alert];

local findAlert(groups, alert) =
  local matching = findAlerts(groups, alert);
  if std.length(matching) == 0 then error 'no alert named %s' % alert else matching[0];

// An empty window list disables the apiserver SLOs. It has to keep emitting no burn rate
// rules and no alerts, rather than failing generation on the empty list.
local noWindows = withApiserverWindows([]);
assert groupRules(noWindows.prometheusRules.groups, 'kube-apiserver-burnrate.rules') == [];
assert groupRules(noWindows.prometheusAlerts.groups, 'kube-apiserver-slos') == [];

// Recording-backed non-API alerts still validate their grouping dependency when API SLO
// windows are disabled, and matching recording/alert grouping remains valid.
local noWindowsAdditionalGrouping = withApiserverWindows([]) {
  _config+:: {
    additionalGrouping+: {
      recordingRules: ['tenant'],
      alertingRules: ['tenant'],
    },
  },
};
assert findAlert(noWindowsAdditionalGrouping.prometheusAlerts.groups, 'KubeletPlegDurationHigh').expr ==
       findAlert(mixin.prometheusAlerts.groups, 'KubeletPlegDurationHigh').expr;

// Windows are ordered by duration, so every Prometheus duration literal has to parse:
// sub-second units, units coarser than a day, and compound values.
local exoticWindows = withApiserverWindows([
  { severity: 'critical', 'for': '2m', long: '1m30s', short: '500ms', factor: 14.4 },
  { severity: 'warning', 'for': '3h', long: '2w', short: '1d12h', factor: 1 },
]);
local exoticRules = groupRules(exoticWindows.prometheusRules.groups, 'kube-apiserver-burnrate.rules');

// The shortest window carries the intermediate series, and only windows longer than the
// longest short window are averaged from them.
assert std.member(recordNames(exoticRules), 'cluster_verb:apiserver_request_sli_bad_events:rate500ms');
assert std.member(recordNames(exoticRules), 'cluster_verb:apiserver_request_sli_events:rate500ms');
assert averagedRecords(exoticRules) == std.set(['apiserver_request:burnrate2w']);

// Valid Prometheus label-name boundaries remain accepted on both configuration paths.
local validGroupingLabels = mixin {
  _config+:: {
    additionalGrouping+: {
      recordingRules: ['_', '_tenant9', 'A0'],
      alertingRules: ['_', '_tenant9', 'A0'],
    },
  },
};
assert std.length(validGroupingLabels.prometheusRules.groups) > 0;
assert std.length(validGroupingLabels.prometheusAlerts.groups) > 0;

// Overriding additionalGrouping without `+` leaves the lists it does not define empty, and the
// label-enrichment wrapper works with a configuration that has no additionalGrouping at all.
local replacedGrouping(additionalGrouping) = mixin {
  _config+:: {
    additionalGrouping: additionalGrouping,
  },
};
assert std.length(replacedGrouping({ recordingRules: ['tenant'] }).prometheusRules.groups) > 0;
assert std.length(replacedGrouping({ recordingRules: ['tenant'] }).prometheusAlerts.groups) > 0;
assert std.length(replacedGrouping({}).prometheusAlerts.groups) > 0;
assert utils.wrap_rule_for_labels(
  { alert: 'KubePodCrashLooping', expr: 'up' },
  { pods_join_labels: ['label_team'], namespaceLabel: 'namespace', clusterLabel: 'cluster' }
).expr == '(up) * on (pod,namespace,cluster) group_left(label_team) kube_pod_labels';

local additionalGrouping = (mixin + (import '../rules/windows.libsonnet')) {
  _config+:: {
    additionalGrouping+: {
      recordingRules: ['tenant', 'namespace', 'tenant'],
    },
  },
};

// Expressions without existing grouping or matching are unchanged by additional grouping.
local defaultWindowsMemory = findRule((mixin + (import '../rules/windows.libsonnet')).prometheusRules.groups, 'node:windows_node_memory_utilisation:ratio');
local groupedWindowsMemory = findRule(additionalGrouping.prometheusRules.groups, 'node:windows_node_memory_utilisation:ratio');
assert std.length(std.findSubstr('scalar(sum(', defaultWindowsMemory.expr)) == 1;
assert groupedWindowsMemory.expr == defaultWindowsMemory.expr;

// Labels supplied through group_left remain payload labels instead of becoming match keys.
// Render the applicable recording rules without kube-scheduler, whose `without(instance, pod)`
// aggregation intentionally rejects this conflict-focused configuration.
local conflictingGrouping = (
  (import '../config.libsonnet') +
  (import '../rules/kube_apiserver.libsonnet') +
  (import '../rules/apps.libsonnet') +
  (import '../rules/node.libsonnet') +
  (import '../rules/kubelet.libsonnet') +
  (import '../rules/windows.libsonnet')
) {
  _config+:: {
    additionalGrouping+: {
      recordingRules: ['node', 'owner_name', 'owner_kind', 'container', 'pod', 'namespace'],
    },
  },
};
local conflictingWindowsAvailable = findRule(conflictingGrouping.prometheusRules.groups, 'windows_pod_container_available');
assert std.length(std.findSubstr('on(container_id, cluster, node, owner_name, owner_kind)', conflictingWindowsAvailable.expr)) == 1;
assert std.length(std.findSubstr('group_left(container, pod, namespace)', conflictingWindowsAvailable.expr)) == 1;
local conflictingAvailability = findRule(conflictingGrouping.prometheusRules.groups, 'apiserver_request:availability30d');
assert std.length(std.findSubstr('sum by (cluster, node, owner_name, owner_kind, container, pod, namespace)', conflictingAvailability.expr)) > 0;
local conflictingKubelet = findRule(conflictingGrouping.prometheusRules.groups, 'node_quantile:kubelet_pleg_relist_duration_seconds:histogram_quantile');
assert std.length(std.findSubstr('on(cluster, instance, owner_name, owner_kind, container, pod, namespace) group_left (node)', conflictingKubelet.expr)) == 1;
local conflictingNodeCPU = findRule(conflictingGrouping.prometheusRules.groups, 'node:node_num_cpu:sum');
assert std.length(std.findSubstr('on (cluster, namespace, pod, owner_name, owner_kind) group_left(node)', conflictingNodeCPU.expr)) == 1;
assert std.length(std.findSubstr('topk by(cluster, namespace, pod, owner_name, owner_kind)', conflictingNodeCPU.expr)) == 1;
local conflictingPodPhase = findRule(conflictingGrouping.prometheusRules.groups, 'cluster:namespace:pod_memory:active:kube_pod_container_resource_requests');
assert std.length(std.findSubstr('on (namespace, pod, cluster, owner_name, owner_kind)', conflictingPodPhase.expr)) == 1;
local conflictingPodOwners = findRules(conflictingGrouping.prometheusRules.groups, 'namespace_workload_pod:kube_pod_owner:relabel');
assert std.length(conflictingPodOwners) == 8;
assert std.length(std.findSubstr('on (cluster, replicaset, namespace, node, container) group_left(owner_name) topk by(cluster, replicaset, namespace, node, container)', conflictingPodOwners[0].expr)) == 1;
assert std.length(std.findSubstr('on (cluster, namespace, job_name, node, container) group_left()', conflictingPodOwners[4].expr)) == 1;
assert std.length(std.findSubstr('group by (cluster, namespace, job_name, node, container)', conflictingPodOwners[4].expr)) == 1;
assert std.length(std.findSubstr('on (cluster, namespace, job_name, node, container) group_left(owner_kind, owner_name)', conflictingPodOwners[7].expr)) == 1;

// Aggregations using `without` are outside of additional grouping and remain unchanged.
assert groupRules(additionalGrouping.prometheusRules.groups, 'kube-scheduler.rules') ==
       groupRules(mixin.prometheusRules.groups, 'kube-scheduler.rules');

local alertGrouping = mixin {
  _config+:: {
    additionalGrouping+: {
      recordingRules: ['tenant'],
      alertingRules: ['tenant', 'cluster', 'tenant'],
    },
    common_join_labels: ['label_team'],
  },
};
local alertGroups = alertGrouping.prometheusAlerts.groups;

// Alert aggregations, matching, and final label-enrichment joins retain the configured
// dimension without duplicating labels already present in the query-specific list.
local groupedPodNotReady = findAlert(alertGroups, 'KubePodNotReady');
assert std.length(std.findSubstr('sum by (namespace, pod, job, cluster, tenant)', groupedPodNotReady.expr)) == 1;
assert std.length(std.findSubstr('on(namespace, pod, cluster, tenant)', groupedPodNotReady.expr)) == 3;
assert std.length(std.findSubstr('on (pod, namespace, cluster, tenant) group_left(label_team)', groupedPodNotReady.expr)) == 1;
assert std.length(std.findSubstr('tenant, tenant', groupedPodNotReady.expr)) == 0;

local groupedAPIBurn = findAlerts(alertGroups, 'KubeAPIErrorBudgetBurn')[0];
assert std.length(std.findSubstr('sum by(cluster, tenant)', groupedAPIBurn.expr)) == 2;
assert std.length(std.findSubstr('and on(cluster, tenant)', groupedAPIBurn.expr)) == 1;

// Native labels emitted by a recording pipeline remain valid alert-only grouping dimensions.
local nativeAPIVerbGrouping = ((import '../config.libsonnet') + (import '../alerts/kube_apiserver.libsonnet')) {
  _config+:: {
    kubeApiserverSelector: 'job="kube-apiserver"',
    additionalGrouping+: {
      alertingRules: ['verb'],
    },
  },
};
local groupedAPIVerb = findAlerts(nativeAPIVerbGrouping.prometheusAlerts.groups, 'KubeAPIErrorBudgetBurn')[0];
assert std.length(std.findSubstr('sum by(cluster, verb)', groupedAPIVerb.expr)) == 2;
assert std.length(std.findSubstr('and on(cluster, verb)', groupedAPIVerb.expr)) == 1;

local groupedCertificate = findAlerts(alertGroups, 'KubeClientCertificateExpiration')[0];
assert std.length(std.findSubstr('sum without (namespace, service, endpoint)', groupedCertificate.expr)) == 1;
assert std.length(std.findSubstr('on(job, cluster, instance, tenant)', groupedCertificate.expr)) == 1;

local groupedKubeletLatency = findAlert(alertGroups, 'KubeletPodStartUpLatencyHigh');
assert std.length(std.findSubstr('sum by (cluster, instance, le, tenant)', groupedKubeletLatency.expr)) == 1;
assert std.length(std.findSubstr('on(cluster, instance, tenant) group_left(node)', groupedKubeletLatency.expr)) == 1;

local groupedQuota = findAlert(alertGroups, 'KubeQuotaAlmostFull');
assert std.length(std.findSubstr('topk by (cluster, namespace, resource, resourcequota, tenant)', groupedQuota.expr)) == 2;
assert std.length(std.findSubstr('on (cluster, namespace, resource, resourcequota, tenant)', groupedQuota.expr)) == 1;
assert std.length(std.findSubstr('max without (instance, job, type)', groupedQuota.expr)) == 2;
// Single-cluster overcommit alerts intentionally aggregate globally. Additional dimensions are
// retained only by the multi-cluster expressions.
local singleClusterOvercommit = findAlert(alertGroups, 'KubeCPUOvercommit');
assert std.length(std.findSubstr('count(max by (node)', singleClusterOvercommit.expr)) == 1;
assert std.length(std.findSubstr('by (node, tenant)', singleClusterOvercommit.expr)) == 0;

local multiClusterAlertGrouping = mixin {
  _config+:: {
    showMultiCluster: true,
    additionalGrouping+: {
      recordingRules: ['tenant'],
      alertingRules: ['tenant'],
    },
  },
};
local groupedMultiClusterOvercommit = findAlert(multiClusterAlertGrouping.prometheusAlerts.groups, 'KubeCPUOvercommit');
assert std.length(std.findSubstr('sum by(cluster, tenant)', groupedMultiClusterOvercommit.expr)) == 3;
assert std.length(std.findSubstr('count by (cluster, tenant) (max by (cluster, node, tenant)', groupedMultiClusterOvercommit.expr)) == 1;

local nativeClusterAlertGrouping = mixin {
  _config+:: {
    showMultiCluster: true,
    additionalGrouping+: {
      alertingRules: ['cluster'],
    },
  },
};
local groupedNativeClusterOvercommit = findAlert(nativeClusterAlertGrouping.prometheusAlerts.groups, 'KubeCPUOvercommit');
assert std.length(std.findSubstr('sum by(cluster)', groupedNativeClusterOvercommit.expr)) == 3;

local groupedVolume = findAlerts(alertGroups, 'KubePersistentVolumeFillingUp')[0];
assert std.length(std.findSubstr('unless on(cluster, namespace, persistentvolumeclaim, tenant)', groupedVolume.expr)) == 2;
local groupedVersion = findAlert(alertGroups, 'KubeVersionMismatch');
assert std.length(std.findSubstr('count by (cluster, tenant) (count by (git_version, cluster, tenant)', groupedVersion.expr)) == 1;
local groupedClientErrors = findAlert(alertGroups, 'KubeClientErrors');
assert std.length(std.findSubstr('by (cluster, instance, job, namespace, tenant)', groupedClientErrors.expr)) == 2;

local joinedWithoutAlertGrouping = mixin {
  _config+:: {
    common_join_labels: ['label_team'],
  },
};
local ungroupedWrappedPod = findAlert(joinedWithoutAlertGrouping.prometheusAlerts.groups, 'KubePodCrashLooping');
assert std.length(std.findSubstr('on (pod,namespace,cluster) group_left(label_team)', ungroupedWrappedPod.expr)) == 1;

local groupedWrappedAlert = mixin {
  _config+:: {
    additionalGrouping+: {
      recordingRules: ['label_team', 'tenant'],
      alertingRules: ['label_team', 'tenant'],
    },
    common_join_labels: ['label_team'],
  },
};
local groupedWrappedPod = findAlert(groupedWrappedAlert.prometheusAlerts.groups, 'KubePodCrashLooping');
assert std.length(std.findSubstr('on (pod, namespace, cluster, tenant) group_left(label_team)', groupedWrappedPod.expr)) == 1;
assert std.length(std.findSubstr('on (', groupedWrappedPod.expr)) == 1;

// Query-specific labels that remain valid dimensions are retained without being copied into
// unsafe matching lists when they are payload labels.
local conflictingAlertGrouping = mixin {
  _config+:: {
    additionalGrouping+: {
      recordingRules: ['eviction_signal', 'operation_type', 'label_team', 'tenant'],
      alertingRules: ['eviction_signal', 'operation_type', 'label_team', 'tenant'],
    },
    common_join_labels: ['label_team'],
  },
};
local conflictingAlertGroups = conflictingAlertGrouping.prometheusAlerts.groups;
local conflictingPodAlert = findAlert(conflictingAlertGroups, 'KubePodNotReady');
assert std.length(std.findSubstr('on(namespace, pod, cluster, eviction_signal, operation_type, label_team, tenant)', conflictingPodAlert.expr)) == 3;
assert std.length(std.findSubstr('on (pod, namespace, cluster, eviction_signal, operation_type, tenant) group_left(label_team)', conflictingPodAlert.expr)) == 1;
local conflictingHPA = findAlert(conflictingAlertGroups, 'KubeHpaMaxedOut');
assert std.length(std.findSubstr('on(namespace, horizontalpodautoscaler, cluster, eviction_signal, operation_type, label_team, tenant)', conflictingHPA.expr)) == 2;
local conflictingKubeletLatency = findAlert(conflictingAlertGroups, 'KubeletPodStartUpLatencyHigh');
assert std.length(std.findSubstr('on(cluster, instance, label_team, tenant) group_left(node)', conflictingKubeletLatency.expr)) == 1;
local conflictingVersion = findAlert(conflictingAlertGroups, 'KubeVersionMismatch');
assert std.length(std.findSubstr('count by (cluster, eviction_signal, operation_type, label_team, tenant)', conflictingVersion.expr)) == 1;
local conflictingClient = findAlert(conflictingAlertGroups, 'KubeClientErrors');
assert std.length(std.findSubstr('by (cluster, instance, job, namespace, eviction_signal, operation_type, label_team, tenant)', conflictingClient.expr)) == 2;
local conflictingVolume = findAlerts(conflictingAlertGroups, 'KubePersistentVolumeFillingUp')[0];
assert std.length(std.findSubstr('unless on(cluster, namespace, persistentvolumeclaim, eviction_signal, operation_type, label_team, tenant)', conflictingVolume.expr)) == 2;

true
