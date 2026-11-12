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
    groups+: [
      {
        name: 'kubernetes-system-kubelet',
        rules: [
          {
            expr: |||
              kube_node_status_condition{%(kubeStateMetricsSelector)s,condition="Ready",status="true"} == 0
              and on (%(clusterLabel)s, node)
              kube_node_spec_unschedulable{%(kubeStateMetricsSelector)s} == 0
            ||| % $._config,
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
              and on (%(clusterLabel)s, node)
              kube_node_spec_unschedulable{%(kubeStateMetricsSelector)s} == 0
            ||| % $._config,
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
                max by (%(clusterLabel)s, instance) (
                  kubelet_running_pods{%(kubeletSelector)s} > 1
                )
                * on (%(clusterLabel)s, instance) group_left(node)
                max by (%(clusterLabel)s, instance, node) (
                  kubelet_node_name{%(kubeletSelector)s}
                )
              )
              / on (%(clusterLabel)s, node) group_left()
              max by (%(clusterLabel)s, node) (
                kube_node_status_capacity{%(kubeStateMetricsSelector)s, resource="pods"} != 1
              ) > 0.95
            ||| % $._config,
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
              sum(changes(kube_node_status_condition{%(kubeStateMetricsSelector)s,status="true",condition="Ready"}[15m])) by (%(clusterLabel)s, node) > 2
              and on (%(clusterLabel)s, node)
              kube_node_spec_unschedulable{%(kubeStateMetricsSelector)s} == 0
            ||| % $._config,
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
              sum(rate(kubelet_evictions{%(kubeletSelector)s}[15m])) by(%(clusterLabel)s, eviction_signal, instance)
              * on (%(clusterLabel)s, instance) group_left(node)
              max by (%(clusterLabel)s, instance, node) (
                kubelet_node_name{%(kubeletSelector)s}
              )
              > %(KubeNodeEvictionRateThreshold)s
            ||| % $._config,
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
            expr: |||
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
                sum by (%(clusterLabel)s, instance, le) (
                  topk by (%(clusterLabel)s, instance, le) (1,
                    rate(kubelet_pod_start_sli_duration_seconds_bucket{%(kubeletSelector)s}[5m])
                  )
                )
              )
              * on(%(clusterLabel)s, instance) group_left(node)
              topk by (%(clusterLabel)s, instance, node) (1,
                kubelet_node_name{%(kubeletSelector)s}
              )
              > 60
            ||| % $._config,
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
              count by (%(clusterLabel)s) (kube_node_info{%(kubeStateMetricsSelector)s})
              unless on (%(clusterLabel)s)
              count by (%(clusterLabel)s) (up{%(kubeletSelector)s} == 1)
            ||| % $._config,
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
