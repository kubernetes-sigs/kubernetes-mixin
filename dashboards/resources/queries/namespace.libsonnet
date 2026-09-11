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
  // CPU Utilization Stat Queries
  cpuUtilisationFromRequests(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace"})) / sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", resource="cpu"})' % config,

  cpuUtilisationFromLimits(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace"})) / sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", resource="cpu"})' % config,

  memoryUtilisationFromRequests(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace",container!="", image!=""})) / sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", resource="memory"})' % config,

  memoryUtilisationFromLimits(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace",container!="", image!=""})) / sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", resource="memory"})' % config,

  // CPU Usage TimeSeries Queries
  cpuUsageByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod)' % config,

  cpuQuotaRequests(config)::
    'scalar(max(kube_resourcequota{%(clusterLabel)s="$cluster", namespace="$namespace", type="hard",resource="requests.cpu"}))' % config,

  cpuQuotaLimits(config)::
    'scalar(max(kube_resourcequota{%(clusterLabel)s="$cluster", namespace="$namespace", type="hard",resource="limits.cpu"}))' % config,

  // CPU Quota Table Queries
  cpuRequestsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod)' % config,

  cpuUsageVsRequests(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod)' % config,

  cpuLimitsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod)' % config,

  cpuUsageVsLimits(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod)' % config,

  cpuThrottling(config):: |||
    sum(increase(container_cpu_cfs_throttled_periods_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])) by (pod)
    /
    sum(increase(container_cpu_cfs_periods_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])) by (pod)
  ||| % config,

  cpuThrottledSeconds(config)::
    'sum(increase(container_cpu_cfs_throttled_seconds_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  // Memory Usage TimeSeries Queries
  memoryUsageByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", container!="", image!=""})) by (pod)' % config,

  memoryQuotaRequests(config)::
    'scalar(max(kube_resourcequota{%(clusterLabel)s="$cluster", namespace="$namespace", type="hard",resource="requests.memory"}))' % config,

  memoryQuotaLimits(config)::
    'scalar(max(kube_resourcequota{%(clusterLabel)s="$cluster", namespace="$namespace", type="hard",resource="limits.memory"}))' % config,

  // Memory Quota Table Queries
  memoryRequestsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod)' % config,

  memoryUsageVsRequests(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace",container!="", image!=""})) by (pod) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod)' % config,

  memoryLimitsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod)' % config,

  memoryUsageVsLimits(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace",container!="", image!=""})) by (pod) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace"})) by (pod)' % config,

  memoryUsageRSS(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace",container!=""})) by (pod)' % config,

  memoryUsageCache(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_cache{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace",container!=""})) by (pod)' % config,

  memoryUsageSwap(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_swap{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace",container!=""})) by (pod)' % config,

  // Network Table Queries
  networkReceiveBandwidth(config)::
    'sum((%(multiplier)s * rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s]))) by (pod)' % (config { multiplier: config.units.networkMultiplier }),

  networkTransmitBandwidth(config)::
    'sum((%(multiplier)s * rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s]))) by (pod)' % (config { multiplier: config.units.networkMultiplier }),

  networkReceivePackets(config)::
    'sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  networkTransmitPackets(config)::
    'sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  networkReceivePacketsDropped(config)::
    'sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  networkTransmitPacketsDropped(config)::
    'sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  networkReceiveBandwidthTimeSeries(config)::
    'sum((%(multiplier)s * rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s]))) by (pod)' % (config { multiplier: config.units.networkMultiplier }),

  networkTransmitBandwidthTimeSeries(config)::
    'sum((%(multiplier)s * rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s]))) by (pod)' % (config { multiplier: config.units.networkMultiplier }),

  // Storage TimeSeries Queries
  iopsReadsWrites(config)::
    'ceil(sum by(pod) (rate(container_fs_reads_total{%(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])))' % config,

  throughputReadWrite(config)::
    'sum by(pod) (rate(container_fs_reads_bytes_total{%(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))' % config,

  // Storage Table Queries
  storageReads(config)::
    'sum by(pod) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))' % config,

  storageWrites(config)::
    'sum by(pod) (rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))' % config,

  storageReadsPlusWrites(config)::
    'sum by(pod) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))' % config,

  storageReadBytes(config)::
    'sum by(pod) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))' % config,

  storageWriteBytes(config)::
    'sum by(pod) (rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))' % config,

  storageReadPlusWriteBytes(config)::
    'sum by(pod) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))' % config,
}
