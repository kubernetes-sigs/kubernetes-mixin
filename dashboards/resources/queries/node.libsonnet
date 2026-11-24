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
  // CPU Queries
  cpuCapacity(config)::
    'sum(kube_node_status_capacity{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="cpu"})' % config,

  cpuAllocatable(config)::
    'sum(kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="cpu"})' % config,

  cpuUsageByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  // CPU Quota Table Queries
  cpuRequestsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  cpuUsageVsRequests(config)::
    '%s / %s' % [self.cpuUsageByPod(config), self.cpuRequestsByPod(config)],

  cpuLimitsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  cpuUsageVsLimits(config)::
    '%s / %s' % [self.cpuUsageByPod(config), self.cpuLimitsByPod(config)],

  // Memory Queries
  memoryCapacity(config)::
    'sum(kube_node_status_capacity{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="memory"})' % config,

  memoryAllocatable(config)::
    'sum(kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="memory"})' % config,

  memoryUsageWSByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node=~"$node", container!=""})) by (pod)' % config,

  memoryUsageRSSByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_memory_rss{%(clusterLabel)s="$cluster", node=~"$node", container!=""})) by (pod)' % config,

  // Memory Quota Table Queries
  memoryUsageWSByPodTable(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node=~"$node",container!=""})) by (pod)' % config,

  memoryRequestsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  memoryUsageVsRequests(config)::
    '%s / %s' % [self.memoryUsageWSByPodTable(config), self.memoryRequestsByPod(config)],

  memoryLimitsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  memoryUsageVsLimits(config)::
    '%s / %s' % [self.memoryUsageWSByPodTable(config), self.memoryLimitsByPod(config)],

  memoryUsageRSSByPodTable(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_memory_rss{%(clusterLabel)s="$cluster", node=~"$node",container!=""})) by (pod)' % config,

  memoryUsageCacheByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_memory_cache{%(clusterLabel)s="$cluster", node=~"$node",container!=""})) by (pod)' % config,

  memoryUsageSwapByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_memory_swap{%(clusterLabel)s="$cluster", node=~"$node",container!=""})) by (pod)' % config,

  // Memory Compaction Queries
  memoryCompactionStallRate(config)::
    'sum(rate(node_vmstat_compact_stall{%(clusterLabel)s="$cluster", %(nodeExporterSelector)s, node=~"$node"}[%(grafanaIntervalVar)s]))' % config,

  memoryCompactionFailRate(config)::
    'sum(rate(node_vmstat_compact_fail{%(clusterLabel)s="$cluster", %(nodeExporterSelector)s, node=~"$node"}[%(grafanaIntervalVar)s]))' % config,

  memoryCompactionSuccessRate(config)::
    'sum(rate(node_vmstat_compact_success{%(clusterLabel)s="$cluster", %(nodeExporterSelector)s, node=~"$node"}[%(grafanaIntervalVar)s]))' % config,

  memoryCompactionDaemonWakeRate(config)::
    'sum(rate(node_vmstat_compact_daemon_wake{%(clusterLabel)s="$cluster", %(nodeExporterSelector)s, node=~"$node"}[%(grafanaIntervalVar)s]))' % config,
}
