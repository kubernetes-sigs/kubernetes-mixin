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

// An empty window list disables the apiserver SLOs. It has to keep emitting no burn rate
// rules and no alerts, rather than failing generation on the empty list.
local noWindows = withApiserverWindows([]);
assert groupRules(noWindows.prometheusRules.groups, 'kube-apiserver-burnrate.rules') == [];
assert groupRules(noWindows.prometheusAlerts.groups, 'kube-apiserver-slos') == [];

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

// Grouping labels keep the query-specific order, append additional labels in their configured
// order, and omit labels that have already appeared in either list.
assert utils.groupingLabels(
  ['cluster', 'namespace'],
  ['tenant', 'namespace', 'tenant']
) == 'cluster, namespace, tenant';
assert utils.withoutLabels(['tenant', 'namespace', 'tenant'], ['namespace']) == ['tenant', 'tenant'];

local additionalGrouping = (mixin + (import '../rules/windows.libsonnet')) {
  _config+:: {
    additionalGrouping+: {
      recordingRules: ['tenant', 'namespace', 'tenant'],
    },
  },
};

// Labels supplied through group_left remain payload labels instead of becoming match keys, and
// labels overwritten by a recording rule are not retained as additional dimensions.
local conflictingGrouping = (mixin + (import '../rules/windows.libsonnet')) {
  _config+:: {
    additionalGrouping+: {
      recordingRules: ['node', 'owner_name', 'owner_kind', 'container', 'pod', 'namespace', 'verb', 'quantile', 'workload_type'],
    },
  },
};
local conflictingWindowsAvailable = findRule(conflictingGrouping.prometheusRules.groups, 'windows_pod_container_available');
assert std.length(std.findSubstr('on(container_id, cluster, node, owner_name, owner_kind, verb, quantile, workload_type)', conflictingWindowsAvailable.expr)) == 1;
assert std.length(std.findSubstr('group_left(container, pod, namespace)', conflictingWindowsAvailable.expr)) == 1;
local conflictingAvailability = findRule(conflictingGrouping.prometheusRules.groups, 'apiserver_request:availability30d');
assert std.length(std.findSubstr('sum by (cluster, node, owner_name, owner_kind, container, pod, namespace, quantile, workload_type)', conflictingAvailability.expr)) > 0;
local conflictingKubelet = findRule(conflictingGrouping.prometheusRules.groups, 'node_quantile:kubelet_pleg_relist_duration_seconds:histogram_quantile');
assert std.length(std.findSubstr('on(cluster, instance, owner_name, owner_kind, container, pod, namespace, verb, workload_type) group_left (node)', conflictingKubelet.expr)) == 1;
local conflictingNodeCPU = findRule(conflictingGrouping.prometheusRules.groups, 'node:node_num_cpu:sum');
assert std.length(std.findSubstr('on (cluster, namespace, pod, owner_name, owner_kind, container, verb, quantile, workload_type) group_left(node)', conflictingNodeCPU.expr)) == 1;
assert std.length(std.findSubstr('topk by(cluster, namespace, pod, owner_name, owner_kind, container, verb, quantile, workload_type)', conflictingNodeCPU.expr)) == 1;
local conflictingPodPhase = findRule(conflictingGrouping.prometheusRules.groups, 'cluster:namespace:pod_memory:active:kube_pod_container_resource_requests');
assert std.length(std.findSubstr('on (namespace, pod, cluster, owner_name, owner_kind, verb, quantile)', conflictingPodPhase.expr)) == 1;
local conflictingPodOwners = findRules(conflictingGrouping.prometheusRules.groups, 'namespace_workload_pod:kube_pod_owner:relabel');
assert std.length(conflictingPodOwners) == 8;
assert std.length(std.findSubstr('on (cluster, replicaset, namespace, node, container, verb, quantile) group_left(owner_name) topk by(cluster, replicaset, namespace, node, container, verb, quantile)', conflictingPodOwners[0].expr)) == 1;
assert std.length(std.findSubstr('on (cluster, namespace, job_name, node, container, verb, quantile) group_left()', conflictingPodOwners[4].expr)) == 1;
assert std.length(std.findSubstr('group by (cluster, namespace, job_name, node, container, verb, quantile)', conflictingPodOwners[4].expr)) == 1;
assert std.length(std.findSubstr('on (cluster, namespace, job_name, node, container, verb, quantile) group_left(owner_kind, owner_name)', conflictingPodOwners[7].expr)) == 1;

// Labels with different meanings across API-server SLO operands do not split only one side of
// the arithmetic. Other additional dimensions continue to be retained.
local sloGrouping = mixin {
  _config+:: {
    additionalGrouping+: {
      recordingRules: ['verb', 'code', 'le', 'resource', 'scope', 'tenant'],
    },
  },
};
local sloAvailability = findRule(sloGrouping.prometheusRules.groups, 'apiserver_request:availability30d');
assert std.length(std.findSubstr('sum by (cluster, tenant)', sloAvailability.expr)) > 0;
assert std.length(std.findSubstr('sum by (cluster, tenant,', sloAvailability.expr)) == 0;
local sloBadEvents = findRule(sloGrouping.prometheusRules.groups, 'cluster_verb:apiserver_request_sli_bad_events:rate5m');
assert std.length(std.findSubstr('sum by (cluster, tenant)', sloBadEvents.expr)) > 0;
assert std.length(std.findSubstr('sum by (cluster, tenant,', sloBadEvents.expr)) == 0;

// Aggregations using `without` are outside of additional grouping and remain unchanged.
assert groupRules(additionalGrouping.prometheusRules.groups, 'kube-scheduler.rules') ==
       groupRules(mixin.prometheusRules.groups, 'kube-scheduler.rules');

true
