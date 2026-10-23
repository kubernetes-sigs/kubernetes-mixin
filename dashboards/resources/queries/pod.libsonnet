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
  cpuUsageByContainer(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{namespace="$namespace", pod="$pod", %(clusterLabel)s="$cluster", container!=""})) by (container)' % config,

  cpuRequests(config)::
    |||
      sum(
          kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="cpu"}
      )
    ||| % config,

  cpuLimits(config)::
    |||
      sum(
          kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="cpu"}
      )
    ||| % config,

  cpuThrottling(config)::
    'sum(increase(container_cpu_cfs_throttled_periods_total{%(cadvisorSelector)s, namespace="$namespace", pod="$pod", container!="", %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (container) /sum(increase(container_cpu_cfs_periods_total{%(cadvisorSelector)s, namespace="$namespace", pod="$pod", container!="", %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (container)' % config,

  cpuThrottledSeconds(config)::
    'sum(increase(container_cpu_cfs_throttled_seconds_total{%(cadvisorSelector)s, namespace="$namespace", pod="$pod", container!="", %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (container)' % config,

  // CPU Quota Table Queries
  cpuRequestsByContainer(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""})) by (container)' % config,

  cpuUsageVsRequests(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""})) by (container) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""})) by (container)' % config,

  cpuLimitsByContainer(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""})) by (container)' % config,

  cpuUsageVsLimits(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""})) by (container) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""})) by (container)' % config,

  // Memory Queries
  memoryUsageWSS(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="", image!=""})) by (container)' % config,

  memoryRequests(config)::
    |||
      sum(
          kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="memory"}
      )
    ||| % config,

  memoryLimits(config)::
    |||
      sum(
          kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="memory"}
      )
    ||| % config,

  // Memory Quota Table Queries
  memoryRequestsByContainer(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"})) by (container)' % config,

  memoryUsageVsRequests(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", image!=""})) by (container) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"})) by (container)' % config,

  memoryLimitsByContainer(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"})) by (container)' % config,

  memoryUsageVsLimits(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="", image!=""})) by (container) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"})) by (container)' % config,

  memoryUsageRSS(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"})) by (container)' % config,

  memoryUsageCache(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_cache{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"})) by (container)' % config,

  memoryUsageSwap(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_swap{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"})) by (container)' % config,

  // Network Queries
  networkReceiveBandwidth(config)::
    'sum((%(multiplier)s * irate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))) by (pod)' % (config { multiplier: config.units.networkMultiplier }),

  networkTransmitBandwidth(config)::
    'sum((%(multiplier)s * rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))) by (pod)' % (config { multiplier: config.units.networkMultiplier }),

  networkReceivePackets(config)::
    'sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  networkTransmitPackets(config)::
    'sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  networkReceivePacketsDropped(config)::
    'sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  networkTransmitPacketsDropped(config)::
    'sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  // Storage Queries - Pod Level
  iopsPodReads(config)::
    'ceil(sum by(pod) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])))' % config,

  iopsPodWrites(config)::
    'ceil(sum by(pod) (rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster",namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])))' % config,

  throughputPodRead(config)::
    'sum by(pod) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % config,

  throughputPodWrite(config)::
    'sum by(pod) (rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % config,

  // Storage Queries - Container Level
  iopsContainersCombined(config)::
    'ceil(sum by(container) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s])))' % config,

  throughputContainersCombined(config)::
    'sum by(container) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % config,

  // Storage Table Queries
  storageReads(config)::
    'sum by(container) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % config,

  storageWrites(config)::
    'sum by(container) (rate(container_fs_writes_total{%(cadvisorSelector)s,%(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % config,

  storageReadsPlusWrites(config)::
    'sum by(container) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % config,

  storageReadBytes(config)::
    'sum by(container) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % config,

  storageWriteBytes(config)::
    'sum by(container) (rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % config,

  storageReadPlusWriteBytes(config)::
    'sum by(container) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % config,
}
