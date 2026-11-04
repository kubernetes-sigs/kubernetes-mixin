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

local utils = import '../lib/utils.libsonnet';

{
  // The overcommit expressions cannot preserve these labels, because they do not exist on every
  // operand. The labels are rejected in every mode, so a configuration does not start failing
  // when showMultiCluster is turned on.
  local grouping = utils.grouping(
    $._config,
    'alertingRules',
    'kubernetes-resources alerting rules',
    [
      $._config.namespaceLabel,
      'namespace',
      'pod',
      'container',
      'workload',
      'workload_type',
      'owner_name',
      'owner_kind',
      'replicaset',
      'job_name',
      'daemonset',
      'deployment',
      'statefulset',
      'horizontalpodautoscaler',
      'poddisruptionbudget',
      'phase',
      'condition',
      'reason',
      'uid',
      'priority',
      'priority_class',
      'scheduler',
      'resourcequota',
      'role',
      'unit',
    ],
    ['resource', 'instance', 'job', 'type', 'id', 'metrics_path', 'name', 'image', 'endpoint', 'node']
  ),
  local config = $._config {
    groupingClusterOvercommit: grouping.by([$._config.clusterLabel]),
    groupingClusterNodeOvercommit: grouping.by([$._config.clusterLabel, 'node']),
    groupingQuotaIdentity: grouping.by([$._config.clusterLabel, $._config.namespaceLabel, 'resource', 'resourcequota']),
    groupingContainerIdentity: grouping.by([$._config.clusterLabel, $._config.namespaceLabel, 'pod', 'container', 'instance']),
  },

  local kubeOvercommitExpression(resource) = if $._config.showMultiCluster then
    |||
      # Non-HA clusters.
      (
        (
          sum by(%(groupingClusterOvercommit)s) (namespace_%(resource)s:kube_pod_container_resource_requests:sum{%(ignoringOverprovisionedWorkloadSelector)s})
          -
          sum by(%(groupingClusterOvercommit)s) (kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="%(resource)s"}) > 0
        )
        and
        count by (%(groupingClusterOvercommit)s) (max by (%(groupingClusterNodeOvercommit)s) (kube_node_role{%(kubeStateMetricsSelector)s, role="control-plane"})) < 3
      )
      or
      # HA clusters.
      (
        sum by(%(groupingClusterOvercommit)s) (namespace_%(resource)s:kube_pod_container_resource_requests:sum{%(ignoringOverprovisionedWorkloadSelector)s})
        -
        (
          # Skip clusters with only one allocatable node.
          (
            sum by (%(groupingClusterOvercommit)s) (kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="%(resource)s"})
            -
            max by (%(groupingClusterOvercommit)s) (kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="%(resource)s"})
          ) > 0
        ) > 0
      )
    ||| % config { resource: resource }
  else
    // Single-cluster mode intentionally aggregates globally and does not retain
    // configured additional grouping dimensions.
    |||
      # Non-HA clusters.
      (
        (
          sum(namespace_%(resource)s:kube_pod_container_resource_requests:sum{%(ignoringOverprovisionedWorkloadSelector)s})
          -
          sum(kube_node_status_allocatable{resource="%(resource)s", %(kubeStateMetricsSelector)s}) > 0
        )
        and
        count(max by (node) (kube_node_role{%(kubeStateMetricsSelector)s, role="control-plane"})) < 3
      )
      or
      # HA clusters.
      (
        sum(namespace_%(resource)s:kube_pod_container_resource_requests:sum{%(ignoringOverprovisionedWorkloadSelector)s})
        -
        (
          # Skip clusters with only one allocatable node.
          (
            sum(kube_node_status_allocatable{resource="%(resource)s", %(kubeStateMetricsSelector)s})
            -
            max(kube_node_status_allocatable{resource="%(resource)s", %(kubeStateMetricsSelector)s})
          ) > 0
        ) > 0
      )
    ||| % config { resource: resource },

  local kubeQuotaOvercommitExpression(resource) = if $._config.showMultiCluster then
    |||
      sum by(%(groupingClusterOvercommit)s) (
        min without(resource) (kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard", resource=~"(%(resource)s|requests.%(resource)s)"})
      )
      /
      sum by(%(groupingClusterOvercommit)s) (
        kube_node_status_allocatable{resource="%(resource)s", %(kubeStateMetricsSelector)s}
      ) > %(namespaceOvercommitFactor)s
    ||| % config { resource: resource }
  else
    // Single-cluster mode intentionally aggregates globally and does not retain
    // configured additional grouping dimensions.
    |||
      sum (
        min without(resource) (kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard", resource=~"(%(resource)s|requests.%(resource)s)"})
      )
      /
      sum (
        kube_node_status_allocatable{resource="%(resource)s", %(kubeStateMetricsSelector)s}
      ) > %(namespaceOvercommitFactor)s
    ||| % config { resource: resource },

  _config+:: {
    kubeStateMetricsSelector: error 'must provide selector for kube-state-metrics',
    nodeExporterSelector: error 'must provide selector for node-exporter',
    namespaceSelector: null,
    prefixedNamespaceSelector: if self.namespaceSelector != null then self.namespaceSelector + ',' else '',

    // We alert when the aggregate (CPU, Memory) quota for all namespaces is
    // greater than the amount of the resources in the cluster.  We do however
    // allow you to overcommit if you wish.
    namespaceOvercommitFactor: 1.5,
    cpuThrottlingPercent: 25,
    cpuThrottlingSelector: '',
    // Set this selector for seleting namespaces that contains resources used for overprovision
    // See https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#how-can-i-configure-overprovisioning-with-cluster-autoscaler
    // for more details.
    ignoringOverprovisionedWorkloadSelector: '',
  },

  prometheusAlerts+:: {
    // The CPU and memory overcommit alerts read recording rules, so their labels must be
    // recorded too. The grouping keys do not check this, so the assert is the only check in
    // both modes.
    assert std.isArray(grouping.requireRecorded([$._config.clusterLabel], 'KubeCPUOvercommit and KubeMemoryOvercommit')),

    groups+: [
      {
        name: 'kubernetes-resources',
        rules: [
          {
            alert: 'KubeCPUOvercommit',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Cluster has overcommitted CPU resource requests.',
              description: 'Cluster%s has overcommitted CPU resource requests for Pods by {{ printf "%%.2f" $value }} CPU shares and cannot tolerate node failure.' % [
                utils.ifShowMultiCluster($._config, ' {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
            },
            'for': '10m',
            expr: kubeOvercommitExpression('cpu'),
          },
          {
            alert: 'KubeMemoryOvercommit',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Cluster has overcommitted memory resource requests.',
              description: 'Cluster%s has overcommitted memory resource requests for Pods by {{ $value | humanize }} bytes and cannot tolerate node failure.' % [
                utils.ifShowMultiCluster($._config, ' {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
            },
            'for': '10m',
            expr: kubeOvercommitExpression('memory'),
          },
          {
            alert: 'KubeCPUQuotaOvercommit',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Cluster has overcommitted CPU resource requests.',
              description: 'Cluster%s has overcommitted CPU resource requests for Namespaces.' % [
                utils.ifShowMultiCluster($._config, ' {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
            },
            expr: kubeQuotaOvercommitExpression('cpu'),
            'for': '5m',
          },
          {
            alert: 'KubeMemoryQuotaOvercommit',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Cluster has overcommitted memory resource requests.',
              description: 'Cluster%s has overcommitted memory resource requests for Namespaces.' % [
                utils.ifShowMultiCluster($._config, ' {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
            },
            expr: kubeQuotaOvercommitExpression('memory'),
            'for': '5m',
          },
          {
            alert: 'KubeQuotaAlmostFull',
            expr: |||
              topk by (%(groupingQuotaIdentity)s) (1,
                max without (instance, job, type) (
                  kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="used"}
                )
              )
              / on (%(groupingQuotaIdentity)s) group_left()
              topk by (%(groupingQuotaIdentity)s) (1,
                max without (instance, job, type) (
                  kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard"}
                ) > 0
              )
              > 0.9 < 1
            ||| % config,
            'for': '15m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: 'Namespace {{ $labels.namespace }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Namespace quota is going to be full.',
            },
          },
          {
            alert: 'KubeQuotaFullyUsed',
            expr: |||
              topk by (%(groupingQuotaIdentity)s) (1,
                max without (instance, job, type) (
                  kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="used"}
                )
              )
              / on (%(groupingQuotaIdentity)s) group_left()
              topk by (%(groupingQuotaIdentity)s) (1,
                max without (instance, job, type) (
                  kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard"}
                ) > 0
              )
              == 1
            ||| % config,
            'for': '15m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: 'Namespace {{ $labels.namespace }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Namespace quota is fully used.',
            },
          },
          {
            alert: 'KubeQuotaExceeded',
            expr: |||
              topk by (%(groupingQuotaIdentity)s) (1,
                max without (instance, job, type) (
                  kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="used"}
                )
              )
              / on (%(groupingQuotaIdentity)s) group_left()
              topk by (%(groupingQuotaIdentity)s) (1,
                max without (instance, job, type) (
                  kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard"}
                ) > 0
              ) > 1
            ||| % config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Namespace {{ $labels.namespace }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Namespace quota has exceeded the limits.',
            },
          },
          {
            alert: 'CPUThrottlingHigh',
            expr: |||
              sum without (id, metrics_path, name, image, endpoint, job, node) (
                topk by (%(groupingContainerIdentity)s) (1,
                  increase(
                    container_cpu_cfs_throttled_periods_total{container!="", %(cadvisorSelector)s, %(cpuThrottlingSelector)s}
                  [5m])
                )
              )
              / on (%(groupingContainerIdentity)s) group_left
              sum without (id, metrics_path, name, image, endpoint, job, node) (
                topk by (%(groupingContainerIdentity)s) (1,
                  increase(
                    container_cpu_cfs_periods_total{%(cadvisorSelector)s, %(cpuThrottlingSelector)s}
                  [5m])
                )
              )
              > ( %(cpuThrottlingPercent)s / 100 )
            ||| % config,
            'for': '15m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: '{{ $value | humanizePercentage }} throttling of CPU in namespace {{ $labels.namespace }} for container {{ $labels.container }} in pod {{ $labels.pod }}%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Processes experience elevated CPU throttling.',
            },
          },
        ],
      },
    ],
  },
}
