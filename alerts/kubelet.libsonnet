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
  _config+:: {
    kubeStateMetricsSelector: error 'must provide selector for kube-state-metrics',
    kubeletSelector: error 'must provide selector for kubelet',
    kubeNodeUnreachableIgnoreKeys: [
      'ToBeDeletedByClusterAutoscaler',
      'cloud.google.com/impending-node-termination',
      'aws-node-termination-handler/spot-itn',
    ],

    kubeletCertExpirationWarningSeconds: 7 * 24 * 3600,
    kubeletCertExpirationCriticalSeconds: 1 * 24 * 3600,

    // Evictions per second that will trigger an alert. The default value will trigger on any evictions.
    KubeNodeEvictionRateThreshold: 0.0,
  },

  prometheusAlerts+:: {
    local additionalGrouping = utils.rejectGroupingLabels(
      $._config.additionalGrouping.alertingRules,
      ['__name__', 'alertname', 'condition', 'instance', 'job', 'le', 'node', 'resource', 'severity', 'status', 'unit'],
      'kubelet alerting rules',
      'additionalGrouping.alertingRules'
    ),
    local groupingLabels(labels, excludedAdditionalLabels=[]) =
      utils.groupingLabels(labels, utils.withoutLabels(additionalGrouping, excludedAdditionalLabels)),
    local config = $._config {
      groupingClusterNode: groupingLabels([$._config.clusterLabel, 'node'], ['condition', 'status']),
      groupingClusterInstance: groupingLabels([$._config.clusterLabel, 'instance'], ['node', 'resource', 'unit']),
      matchingClusterInstance: groupingLabels([$._config.clusterLabel, 'instance'], ['eviction_signal', 'le', 'node', 'operation_type']),
      groupingClusterInstanceNode: groupingLabels([$._config.clusterLabel, 'instance', 'node'], ['eviction_signal', 'le', 'operation_type', 'resource', 'unit']),
      groupingClusterNodeCapacity: groupingLabels([$._config.clusterLabel, 'node'], ['instance', 'job', 'resource', 'unit']),
      matchingClusterNodeCapacity: groupingLabels([$._config.clusterLabel, 'node'], ['instance', 'job', 'resource', 'unit']),
      groupingClusterEvictionSignalInstance: groupingLabels([$._config.clusterLabel, 'eviction_signal', 'instance'], ['node']),
      groupingClusterInstanceLe: groupingLabels([$._config.clusterLabel, 'instance', 'le'], ['node']),
      groupingClusterInstanceLeOperationType: groupingLabels([$._config.clusterLabel, 'instance', 'le', 'operation_type'], ['node']),
      groupingCluster: groupingLabels([$._config.clusterLabel], ['instance', 'job', 'node']),
    },

    groups+: [
      {
        name: 'kubernetes-system-kubelet',
        rules: [
          {
            expr: |||
              kube_node_status_condition{%(kubeStateMetricsSelector)s,condition="Ready",status="true"} == 0
              and on (%(groupingClusterNode)s)
              kube_node_spec_unschedulable{%(kubeStateMetricsSelector)s} == 0
            ||| % config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: '{{ $labels.node }} has been unready for more than 15 minutes%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Node is not ready.',
            },
            'for': '15m',
            alert: 'KubeNodeNotReady',
          },
          {
            alert: 'KubeNodePressure',
            expr: |||
              kube_node_status_condition{%(kubeStateMetricsSelector)s,condition=~"(MemoryPressure|DiskPressure|PIDPressure)",status="true"} == 1
              and on (%(groupingClusterNode)s)
              kube_node_spec_unschedulable{%(kubeStateMetricsSelector)s} == 0
            ||| % config,
            labels: {
              severity: 'info',
            },
            'for': '10m',
            annotations: {
              description: '{{ $labels.node }}%s has active Condition {{ $labels.condition }}. This is caused by resource usage exceeding eviction thresholds.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Node has as active Condition.',
            },
          },
          {
            expr: |||
              (kube_node_spec_taint{%(kubeStateMetricsSelector)s,key="node.kubernetes.io/unreachable",effect="NoSchedule"} unless ignoring(key,value) kube_node_spec_taint{%(kubeStateMetricsSelector)s,key=~"%(kubeNodeUnreachableIgnoreKeys)s"}) == 1
            ||| % $._config {
              kubeNodeUnreachableIgnoreKeys: std.join('|', super.kubeNodeUnreachableIgnoreKeys),
            },
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: '{{ $labels.node }} is unreachable and some workloads may be rescheduled%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Node is unreachable.',
            },
            'for': '15m',
            alert: 'KubeNodeUnreachable',
          },
          {
            alert: 'KubeletTooManyPods',
            // Some node has a capacity of 1 like AWS's Fargate and only exists while a pod is running on it.
            // We have to ignore this special node in the KubeletTooManyPods alert.
            expr: |||
              (
                max by (%(groupingClusterInstance)s) (
                  kubelet_running_pods{%(kubeletSelector)s} > 1
                )
                * on (%(matchingClusterInstance)s) group_left(node)
                max by (%(groupingClusterInstanceNode)s) (
                  kubelet_node_name{%(kubeletSelector)s}
                )
              )
              / on (%(matchingClusterNodeCapacity)s) group_left()
              max by (%(groupingClusterNodeCapacity)s) (
                kube_node_status_capacity{%(kubeStateMetricsSelector)s, resource="pods"} != 1
              ) > 0.95
            ||| % config,
            'for': '15m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: "Kubelet '{{ $labels.node }}' is running at {{ $value | humanizePercentage }} of its Pod capacity%s." % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubelet is running at capacity.',
            },
          },
          {
            alert: 'KubeNodeReadinessFlapping',
            expr: |||
              sum(changes(kube_node_status_condition{%(kubeStateMetricsSelector)s,status="true",condition="Ready"}[15m])) by (%(groupingClusterNode)s) > 2
              and on (%(groupingClusterNode)s)
              kube_node_spec_unschedulable{%(kubeStateMetricsSelector)s} == 0
            ||| % config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'The readiness status of node {{ $labels.node }} has changed {{ $value }} times in the last 15 minutes%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Node readiness status is flapping.',
            },
          },
          {
            alert: 'KubeNodeEviction',
            expr: |||
              sum(rate(kubelet_evictions{%(kubeletSelector)s}[15m])) by(%(groupingClusterEvictionSignalInstance)s)
              * on (%(matchingClusterInstance)s) group_left(node)
              max by (%(groupingClusterInstanceNode)s) (
                kubelet_node_name{%(kubeletSelector)s}
              )
              > %(KubeNodeEvictionRateThreshold)s
            ||| % config,
            labels: {
              severity: 'info',
            },
            'for': '0s',
            annotations: {
              description: 'Node {{ $labels.node }}%s is evicting Pods due to {{ $labels.eviction_signal }}.  Eviction occurs when eviction thresholds are crossed, typically caused by Pods exceeding RAM/ephemeral-storage limits.' % [
                utils.ifShowMultiCluster($._config, ' on {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Node is evicting pods.',
            },
          },
          {
            alert: 'KubeletPlegDurationHigh',
            expr:
              local recordingBackedGrouping = utils.withoutLabels(
                additionalGrouping,
                [$._config.clusterLabel, 'instance', 'node', 'quantile', 'le']
              );
              assert utils.requireAlertGroupingInRecordingRules(
                recordingBackedGrouping,
                $._config.additionalGrouping.recordingRules,
                'KubeletPlegDurationHigh'
              ) == recordingBackedGrouping;
              |||
                node_quantile:kubelet_pleg_relist_duration_seconds:histogram_quantile{quantile="0.99"} >= 10
              ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'The Kubelet Pod Lifecycle Event Generator has a 99th percentile duration of {{ $value }} seconds on node {{ $labels.node }}%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubelet Pod Lifecycle Event Generator is taking too long to relist.',
            },
          },
          {
            alert: 'KubeletPodStartUpLatencyHigh',
            expr: |||
              histogram_quantile(0.99,
                sum by (%(groupingClusterInstanceLe)s) (
                  topk by (%(groupingClusterInstanceLeOperationType)s) (1,
                    rate(kubelet_pod_worker_duration_seconds_bucket{%(kubeletSelector)s}[5m])
                  )
                )
              )
              * on(%(matchingClusterInstance)s) group_left(node)
              topk by (%(groupingClusterInstanceNode)s) (1,
                kubelet_node_name{%(kubeletSelector)s}
              )
              > 60
            ||| % config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Kubelet Pod startup 99th percentile latency is {{ $value }} seconds on node {{ $labels.node }}%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubelet Pod startup latency is too high.',
            },
          },
          {
            alert: 'KubeletClientCertificateExpiration',
            expr: |||
              kubelet_certificate_manager_client_ttl_seconds < %(kubeletCertExpirationWarningSeconds)s
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Client certificate for Kubelet on node {{ $labels.node }} expires in {{ $value | humanizeDuration }}%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubelet client certificate is about to expire.',
            },
          },
          {
            alert: 'KubeletClientCertificateExpiration',
            expr: |||
              kubelet_certificate_manager_client_ttl_seconds < %(kubeletCertExpirationCriticalSeconds)s
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: 'Client certificate for Kubelet on node {{ $labels.node }} expires in {{ $value | humanizeDuration }}%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubelet client certificate is about to expire.',
            },
          },
          {
            alert: 'KubeletServerCertificateExpiration',
            expr: |||
              kubelet_certificate_manager_server_ttl_seconds < %(kubeletCertExpirationWarningSeconds)s
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Server certificate for Kubelet on node {{ $labels.node }} expires in {{ $value | humanizeDuration }}%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubelet server certificate is about to expire.',
            },
          },
          {
            alert: 'KubeletServerCertificateExpiration',
            expr: |||
              kubelet_certificate_manager_server_ttl_seconds < %(kubeletCertExpirationCriticalSeconds)s
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: 'Server certificate for Kubelet on node {{ $labels.node }} expires in {{ $value | humanizeDuration }}%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubelet server certificate is about to expire.',
            },
          },
          {
            alert: 'KubeletClientCertificateRenewalErrors',
            expr: |||
              increase(kubelet_certificate_manager_client_expiration_renew_errors[5m]) > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            'for': '15m',
            annotations: {
              description: 'Kubelet on node {{ $labels.node }} has failed to renew its client certificate ({{ $value | humanize }} errors in the last 5 minutes)%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubelet has failed to renew its client certificate.',
            },
          },
          {
            alert: 'KubeletServerCertificateRenewalErrors',
            expr: |||
              increase(kubelet_server_expiration_renew_errors[5m]) > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            'for': '15m',
            annotations: {
              description: 'Kubelet on node {{ $labels.node }} has failed to renew its server certificate ({{ $value | humanize }} errors in the last 5 minutes)%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubelet has failed to renew its server certificate.',
            },
          },
          (import '../lib/instance_unreachable_alert.libsonnet') {
            componentName:: 'Kubelet',
            selector:: $._config.kubeletSelector,
          },
          {
            // Use kube-state-metrics as an anchor to detect kubelet down while
            // preserving the cluster label. This fires when kube-state-metrics
            // reports nodes exist but no kubelet targets are up for that cluster.
            alert: 'KubeletDown',
            expr: |||
              count by (%(groupingCluster)s) (kube_node_info{%(kubeStateMetricsSelector)s})
              unless on (%(groupingCluster)s)
              count by (%(groupingCluster)s) (up{%(kubeletSelector)s} == 1)
            ||| % config,
            'for': '15m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: 'Kubelet has disappeared from Prometheus target discovery%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Target disappeared from Prometheus target discovery.',
            },
          },
        ],
      },
    ],
  },
}
