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
  // CPU / Memory Queries
  cpuUsage(config):: |||
    sum(
        max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace"})
      * on(%(clusterLabel)s, namespace, pod)
        group_left(workload, workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload=~"$workload", workload_type=~"$type"}
    ) by (pod)
  ||| % config,

  cpuRequests(config):: |||
    sum(
        max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", resource="cpu"})
      * on(%(clusterLabel)s, namespace, pod)
        group_left(workload, workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload=~"$workload", workload_type=~"$type"}
    ) by (pod)
  ||| % config,

  cpuLimits(config):: std.strReplace(self.cpuRequests(config), 'requests', 'limits'),

  cpuThrottling(config):: |||
    sum(
        increase(container_cpu_cfs_throttled_periods_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
      * on(%(clusterLabel)s, namespace, pod)
        group_left(workload, workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload=~"$workload", workload_type=~"$type"}
    ) by (pod)
    /
    sum(
        increase(container_cpu_cfs_periods_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
      * on(%(clusterLabel)s, namespace, pod)
        group_left(workload, workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload=~"$workload", workload_type=~"$type"}
    ) by (pod)
  ||| % config,

  cpuThrottledSeconds(config):: |||
    sum(
        increase(container_cpu_cfs_throttled_seconds_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
      * on(%(clusterLabel)s, namespace, pod)
        group_left(workload, workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload=~"$workload", workload_type=~"$type"}
    ) by (pod)
  ||| % config,

  memUsage(config):: |||
    sum(
        max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", container!="", image!=""})
      * on(%(clusterLabel)s, namespace, pod)
        group_left(workload, workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload=~"$workload", workload_type=~"$type"}
    ) by (pod)
  ||| % config,

  memRequests(config):: std.strReplace(self.cpuRequests(config), 'cpu', 'memory'),

  memLimits(config):: std.strReplace(self.cpuLimits(config), 'cpu', 'memory'),

  // Current Network Usage table columns
  networkColumns(config):: [
    |||
      (sum((%(multiplier)s * rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s]))
      * on (%(clusterLabel)s, namespace, pod)
      group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
    ||| % (config { multiplier: config.units.networkMultiplier }),
    |||
      (sum((%(multiplier)s * rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s]))
      * on (%(clusterLabel)s, namespace, pod)
      group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
    ||| % (config { multiplier: config.units.networkMultiplier }),
    |||
      (sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])
      * on (%(clusterLabel)s, namespace, pod)
      group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
    ||| % config,
    |||
      (sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])
      * on (%(clusterLabel)s, namespace, pod)
      group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
    ||| % config,
    |||
      (sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])
      * on (%(clusterLabel)s, namespace, pod)
      group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
    ||| % config,
    |||
      (sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])
      * on (%(clusterLabel)s, namespace, pod)
      group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
    ||| % config,
  ],

  // Network TimeSeries Queries
  receiveBandwidth(config):: |||
    (sum((%(multiplier)s * rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  transmitBandwidth(config):: |||
    (sum((%(multiplier)s * rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  avgContainerReceiveBandwidth(config):: |||
    (avg((%(multiplier)s * rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  avgContainerTransmitBandwidth(config):: |||
    (avg((%(multiplier)s * rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  rateReceivedPackets(config):: |||
    (sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % config,

  rateTransmittedPackets(config):: |||
    (sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % config,

  rateReceivedPacketsDropped(config):: |||
    (sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % config,

  rateTransmittedPacketsDropped(config):: |||
    (sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % config,
}
