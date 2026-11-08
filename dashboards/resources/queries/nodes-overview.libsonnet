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

{
  // Node & Pod Count
  nodeCount(config)::
    'count(kube_node_info{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s})' % config,

  podCount(config)::
    'sum(kubelet_running_pods{%(clusterLabel)s="$cluster", %(kubeletSelector)s})' % config,

  // CPU
  cpuAllocatable(config)::
    'sum(kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, resource="cpu"})' % config,

  cpuRequests(config)::
    'sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster"})' % config,

  cpuUsage(config)::
    'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})' % config,

  // Memory
  memoryAllocatable(config)::
    'sum(kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, resource="memory"})' % config,

  memoryRequests(config)::
    'sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster"})' % config,

  memoryUsage(config)::
    'sum(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", container!=""})' % config,

  // Per-node utilisation
  cpuUtilizationPerNode(config):: |||
    sum by (node) (node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})
    /
    sum by (node) (kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, resource="cpu"})
  ||| % config,

  memoryUtilizationPerNode(config):: |||
    sum by (node) (node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", container!=""})
    /
    sum by (node) (kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, resource="memory"})
  ||| % config,

  memoryCompactionStallRatePerNode(config)::
    'sum by (node) (rate(node_vmstat_compact_stall{%(clusterLabel)s="$cluster", %(nodeExporterSelector)s}[%(grafanaIntervalVar)s]))' % config,

  memoryCompactionFailRatePerNode(config)::
    'sum by (node) (rate(node_vmstat_compact_fail{%(clusterLabel)s="$cluster", %(nodeExporterSelector)s}[%(grafanaIntervalVar)s]))' % config,

  memoryCompactionSuccessRatePerNode(config)::
    'sum by (node) (rate(node_vmstat_compact_success{%(clusterLabel)s="$cluster", %(nodeExporterSelector)s}[%(grafanaIntervalVar)s]))' % config,

  memoryCompactionDaemonWakeRatePerNode(config)::
    'sum by (node) (rate(node_vmstat_compact_daemon_wake{%(clusterLabel)s="$cluster", %(nodeExporterSelector)s}[%(grafanaIntervalVar)s]))' % config,
}
