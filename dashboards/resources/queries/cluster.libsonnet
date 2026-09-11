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
  cpuUtilisation(config)::
    'cluster:node_cpu:ratio_rate5m{%(clusterLabel)s="$cluster"}' % config,

  cpuRequestsCommitment(config)::
    'sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu",%(clusterLabel)s="$cluster"})' % config,

  cpuLimitsCommitment(config)::
    'sum(namespace_cpu:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu",%(clusterLabel)s="$cluster"})' % config,

  cpuUsageByNamespace(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})) by (namespace)' % config,

  // CPU Quota Table Queries
  podsByNamespace(config)::
    'sum(kube_pod_owner{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster"}) by (namespace)' % config,

  workloadsByNamespace(config)::
    'count(avg(namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster"}) by (workload, namespace)) by (namespace)' % config,

  cpuRequestsByNamespace(config)::
    'sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

  cpuUsageVsRequests(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})) by (namespace) / sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

  cpuLimitsByNamespace(config)::
    'sum(namespace_cpu:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

  cpuUsageVsLimits(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})) by (namespace) / sum(namespace_cpu:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

  cpuThrottling(config):: |||
    sum(increase(container_cpu_cfs_throttled_periods_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (namespace)
    /
    sum(increase(container_cpu_cfs_periods_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (namespace)
  ||| % config,

  cpuThrottledSeconds(config)::
    'sum(increase(container_cpu_cfs_throttled_seconds_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

  // Memory Queries
  memoryUtilisation(config)::
    '1 - sum(:node_memory_MemAvailable_bytes:sum{%(clusterLabel)s="$cluster"}) / sum(node_memory_MemTotal_bytes{%(nodeExporterSelector)s,%(clusterLabel)s="$cluster"})' % config,

  memoryRequestsCommitment(config)::
    'sum(namespace_memory:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="memory",%(clusterLabel)s="$cluster"})' % config,

  memoryLimitsCommitment(config)::
    'sum(namespace_memory:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="memory",%(clusterLabel)s="$cluster"})' % config,

  memoryUsageByNamespace(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""})) by (namespace)' % config,

  // Memory Quota Table Queries
  memoryRequestsByNamespace(config)::
    'sum(namespace_memory:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

  memoryUsageVsRequests(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""})) by (namespace) / sum(namespace_memory:kube_pod_container_resource_requests:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

  memoryLimitsByNamespace(config)::
    'sum(namespace_memory:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

  memoryUsageVsLimits(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""})) by (namespace) / sum(namespace_memory:kube_pod_container_resource_limits:sum{%(clusterLabel)s="$cluster"}) by (namespace)' % config,

  // Network Queries
  networkReceiveBandwidth(config)::
    'sum((%(multiplier)s * rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s]))) by (namespace)' % (config { multiplier: config.units.networkMultiplier }),

  networkTransmitBandwidth(config)::
    'sum((%(multiplier)s * rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s]))) by (namespace)' % (config { multiplier: config.units.networkMultiplier }),

  networkReceivePackets(config)::
    'sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

  networkTransmitPackets(config)::
    'sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

  networkReceivePacketsDropped(config)::
    'sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

  networkTransmitPacketsDropped(config)::
    'sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % config,

  avgContainerReceiveBandwidth(config)::
    'avg((%(multiplier)s * rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s]))) by (namespace)' % (config { multiplier: config.units.networkMultiplier }),

  avgContainerTransmitBandwidth(config)::
    'avg((%(multiplier)s * rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s]))) by (namespace)' % (config { multiplier: config.units.networkMultiplier }),

  // Storage Queries
  iopsReadsWrites(config)::
    'ceil(sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s])))' % config,

  throughputReadWrite(config)::
    'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

  iopsReads(config)::
    'sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

  iopsWrites(config)::
    'sum by(namespace) (rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

  iopsReadsWritesCombined(config)::
    'sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

  throughputRead(config)::
    'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

  throughputWrite(config)::
    'sum by(namespace) (rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,

  throughputReadWriteCombined(config)::
    'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % config,
}
