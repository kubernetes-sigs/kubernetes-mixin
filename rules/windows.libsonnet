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
  prometheusRules+:: {
    local groupingLabels(labels, excludedAdditionalLabels=[]) = utils.groupingLabels(
      labels,
      utils.withoutLabels($._config.additionalGrouping.recordingRules, excludedAdditionalLabels)
    ),
    local config = $._config {
      groupingCluster: groupingLabels([$._config.clusterLabel]),
      groupingClusterInstance: groupingLabels([$._config.clusterLabel, 'instance']),
      groupingClusterInstanceCore: groupingLabels([$._config.clusterLabel, 'instance', 'core']),
      groupingClusterInstanceVolume: groupingLabels([$._config.clusterLabel, 'instance', 'volume']),
      groupingContainerIdCluster: groupingLabels(['container_id', $._config.clusterLabel]),
      groupingContainerContainerIdPodNamespaceCluster: groupingLabels(['container', 'container_id', 'pod', 'namespace', $._config.clusterLabel]),
      groupingClusterNamespacePodContainer: groupingLabels([$._config.clusterLabel, 'namespace', 'pod', 'container']),
      groupingContainerPodNamespaceCluster: groupingLabels(['container', 'pod', 'namespace', $._config.clusterLabel]),
      matchingContainerIdCluster: groupingLabels(['container_id', $._config.clusterLabel], ['container', 'pod', 'namespace']),
      matchingContainerPodNamespaceCluster: groupingLabels(['container', 'pod', 'namespace', $._config.clusterLabel], ['resource', 'unit']),
    },

    groups+: [
      {
        name: 'windows.node.rules',
        rules: [
          {
            // This rule gives the number of windows nodes
            record: 'node:windows_node:sum',
            expr: |||
              count by (%(groupingCluster)s) (
                windows_system_boot_time_timestamp_seconds{%(windowsExporterSelector)s}
              )
            ||| % config,
          },
          {
            // This rule gives the number of CPUs per node.
            record: 'node:windows_node_num_cpu:sum',
            expr: |||
              count by (%(groupingClusterInstance)s) (sum by (%(groupingClusterInstanceCore)s) (
                windows_cpu_time_total{%(windowsExporterSelector)s}
              ))
            ||| % config,
          },
          {
            // CPU utilisation is % CPU is not idle.
            record: ':windows_node_cpu_utilisation:avg1m',
            expr: |||
              1 - avg by (%(groupingCluster)s) (rate(windows_cpu_time_total{%(windowsExporterSelector)s,mode="idle"}[1m]))
            ||| % config,
          },
          {
            // CPU utilisation is % CPU is not idle.
            record: 'node:windows_node_cpu_utilisation:avg1m',
            expr: |||
              1 - avg by (%(groupingClusterInstance)s) (
                rate(windows_cpu_time_total{%(windowsExporterSelector)s,mode="idle"}[1m])
              )
            ||| % config,
          },
          {
            record: ':windows_node_memory_utilisation:',
            expr: |||
              1 -
              sum by (%(groupingCluster)s) (windows_memory_available_bytes{%(windowsExporterSelector)s})
              /
              sum by (%(groupingCluster)s) (windows_os_visible_memory_bytes{%(windowsExporterSelector)s})
            ||| % config,
          },
          // Add separate rules for Free & Total, so we can aggregate across clusters
          // in dashboards.
          {
            record: ':windows_node_memory_MemFreeCached_bytes:sum',
            expr: |||
              sum by (%(groupingCluster)s) (windows_memory_available_bytes{%(windowsExporterSelector)s} + windows_memory_cache_bytes{%(windowsExporterSelector)s})
            ||| % config,
          },
          {
            record: 'node:windows_node_memory_totalCached_bytes:sum',
            expr: |||
              (windows_memory_cache_bytes{%(windowsExporterSelector)s} + windows_memory_modified_page_list_bytes{%(windowsExporterSelector)s} + windows_memory_standby_cache_core_bytes{%(windowsExporterSelector)s} + windows_memory_standby_cache_normal_priority_bytes{%(windowsExporterSelector)s} + windows_memory_standby_cache_reserve_bytes{%(windowsExporterSelector)s})
            ||| % $._config,
          },
          {
            record: ':windows_node_memory_MemTotal_bytes:sum',
            expr: |||
              sum by (%(groupingCluster)s) (windows_os_visible_memory_bytes{%(windowsExporterSelector)s})
            ||| % config,
          },
          {
            // Available memory per node
            // SINCE 2018-02-08
            record: 'node:windows_node_memory_bytes_available:sum',
            expr: |||
              sum by (%(groupingClusterInstance)s) (
                (windows_memory_available_bytes{%(windowsExporterSelector)s})
              )
            ||| % config,
          },
          {
            // Total memory per node
            record: 'node:windows_node_memory_bytes_total:sum',
            expr: |||
              sum by (%(groupingClusterInstance)s) (
                windows_os_visible_memory_bytes{%(windowsExporterSelector)s}
              )
            ||| % config,
          },
          {
            // Memory utilisation per node, normalized by per-node memory
            record: 'node:windows_node_memory_utilisation:ratio',
            expr: |||
              (node:windows_node_memory_bytes_total:sum - node:windows_node_memory_bytes_available:sum)
              /
              scalar(sum(node:windows_node_memory_bytes_total:sum))
            |||,
          },
          {
            record: 'node:windows_node_memory_utilisation:',
            expr: |||
              1 - (node:windows_node_memory_bytes_available:sum / node:windows_node_memory_bytes_total:sum)
            ||| % $._config,
          },
          {
            record: 'node:windows_node_memory_swap_io_pages:irate',
            expr: |||
              irate(windows_memory_swap_page_operations_total{%(windowsExporterSelector)s}[5m])
            ||| % $._config,
          },
          {
            // Disk utilisation (ms spent, by rate() it's bound by 1 second)
            record: ':windows_node_disk_utilisation:avg_irate',
            expr: |||
              avg by (%(groupingCluster)s) (irate(windows_logical_disk_read_seconds_total{%(windowsExporterSelector)s}[1m]) +
                  irate(windows_logical_disk_write_seconds_total{%(windowsExporterSelector)s}[1m])
                )
            ||| % config,
          },
          {
            // Disk utilisation (ms spent, by rate() it's bound by 1 second)
            record: 'node:windows_node_disk_utilisation:avg_irate',
            expr: |||
              avg by (%(groupingClusterInstance)s) (
                (irate(windows_logical_disk_read_seconds_total{%(windowsExporterSelector)s}[1m]) +
                irate(windows_logical_disk_write_seconds_total{%(windowsExporterSelector)s}[1m]))
              )
            ||| % config,
          },
          {
            record: 'node:windows_node_filesystem_usage:',
            expr: |||
              max by (%(groupingClusterInstanceVolume)s)(
                (windows_logical_disk_size_bytes{%(windowsExporterSelector)s} -
                windows_logical_disk_free_bytes{%(windowsExporterSelector)s})
                /
                windows_logical_disk_size_bytes{%(windowsExporterSelector)s}
              )
            ||| % config,
          },
          {
            record: 'node:windows_node_filesystem_avail:',
            expr: |||
              max by (%(groupingClusterInstanceVolume)s) (windows_logical_disk_free_bytes{%(windowsExporterSelector)s} / windows_logical_disk_size_bytes{%(windowsExporterSelector)s})
            ||| % config,
          },
          {
            record: ':windows_node_net_utilisation:sum_irate',
            expr: |||
              sum by (%(groupingCluster)s) (irate(windows_net_bytes_total{%(windowsExporterSelector)s}[1m]))
            ||| % config,
          },
          {
            record: 'node:windows_node_net_utilisation:sum_irate',
            expr: |||
              sum by (%(groupingClusterInstance)s) (
                (irate(windows_net_bytes_total{%(windowsExporterSelector)s}[1m]))
              )
            ||| % config,
          },
          {
            record: ':windows_node_net_saturation:sum_irate',
            expr: |||
              sum by (%(groupingCluster)s) (irate(windows_net_packets_received_discarded_total{%(windowsExporterSelector)s}[1m])) +
              sum by (%(groupingCluster)s) (irate(windows_net_packets_outbound_discarded_total{%(windowsExporterSelector)s}[1m]))
            ||| % config,
          },
          {
            record: 'node:windows_node_net_saturation:sum_irate',
            expr: |||
              sum by (%(groupingClusterInstance)s) (
                (irate(windows_net_packets_received_discarded_total{%(windowsExporterSelector)s}[1m]) +
                irate(windows_net_packets_outbound_discarded_total{%(windowsExporterSelector)s}[1m]))
              )
            ||| % config,
          },
        ],
      },
      {
        name: 'windows.pod.rules',
        rules: [
          {
            record: 'windows_pod_container_available',
            expr: |||
              windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(%(matchingContainerIdCluster)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(%(groupingContainerContainerIdPodNamespaceCluster)s)
            ||| % config,
          },
          {
            record: 'windows_container_total_runtime',
            expr: |||
              windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(%(matchingContainerIdCluster)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(%(groupingContainerContainerIdPodNamespaceCluster)s)
            ||| % config,
          },
          {
            record: 'windows_container_memory_usage',
            expr: |||
              windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(%(matchingContainerIdCluster)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(%(groupingContainerContainerIdPodNamespaceCluster)s)
            ||| % config,
          },
          {
            record: 'windows_container_private_working_set_usage',
            expr: |||
              windows_container_memory_usage_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(%(matchingContainerIdCluster)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(%(groupingContainerContainerIdPodNamespaceCluster)s)
            ||| % config,
          },
          {
            record: 'windows_container_network_received_bytes_total',
            expr: |||
              windows_container_network_receive_bytes_total{%(windowsExporterSelector)s, container_id != ""} * on(%(matchingContainerIdCluster)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(%(groupingContainerContainerIdPodNamespaceCluster)s)
            ||| % config,
          },
          {
            record: 'windows_container_network_transmitted_bytes_total',
            expr: |||
              windows_container_network_transmit_bytes_total{%(windowsExporterSelector)s, container_id != ""} * on(%(matchingContainerIdCluster)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(%(groupingContainerContainerIdPodNamespaceCluster)s)
            ||| % config,
          },
          {
            record: 'kube_pod_windows_container_resource_memory_request',
            expr: |||
              max by (%(groupingClusterNamespacePodContainer)s) (
                kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s}
              ) * on(%(matchingContainerPodNamespaceCluster)s) (windows_pod_container_available)
            ||| % config,
          },
          {
            record: 'kube_pod_windows_container_resource_memory_limit',
            expr: |||
              kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} * on(%(matchingContainerPodNamespaceCluster)s) (windows_pod_container_available)
            ||| % config,
          },
          {
            record: 'kube_pod_windows_container_resource_cpu_cores_request',
            expr: |||
              max by (%(groupingClusterNamespacePodContainer)s) (
                kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s}
              ) * on(%(matchingContainerPodNamespaceCluster)s) (windows_pod_container_available)
            ||| % config,
          },
          {
            record: 'kube_pod_windows_container_resource_cpu_cores_limit',
            expr: |||
              kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} * on(%(matchingContainerPodNamespaceCluster)s) (windows_pod_container_available)
            ||| % config,
          },
          {
            record: 'namespace_pod_container:windows_container_cpu_usage_seconds_total:sum_rate',
            expr: |||
              sum by (%(groupingClusterNamespacePodContainer)s) (
                rate(windows_container_total_runtime{}[5m])
              )
            ||| % config,
          },
        ],
      },
    ],
  },
}
