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
    kubeJobTimeoutDuration: error 'must provide value for kubeJobTimeoutDuration',
    kubeDaemonSetRolloutStuckFor: '15m',
    kubePdbNotEnoughHealthyPodsFor: '15m',
    namespaceSelector: null,
    prefixedNamespaceSelector: if self.namespaceSelector != null then self.namespaceSelector + ',' else '',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-apps',
        rules: [utils.wrap_rule_for_labels(rule, $._config) for rule in self.rules_],
        rules_:: [
          {
            expr: |||
              max_over_time(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff", %(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}[5m]) >= 1
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container }}) is in waiting state (reason: "CrashLoopBackOff")%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Pod is crash looping.',
            },
            'for': '15m',
            alert: 'KubePodCrashLooping',
          },
          {
            // We wrap kube_pod_owner with the topk() aggregator to ensure that
            // every (namespace, pod, %(clusterLabel)s) tuple is unique even if the "owner_kind"
            // label exists for 2 values. This avoids "many-to-many matching
            // not allowed" errors when joining with kube_pod_status_phase.
            expr: |||
              sum by (namespace, pod, job, %(clusterLabel)s) (
                max by(namespace, pod, job, %(clusterLabel)s) (
                  kube_pod_status_phase{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, phase=~"Pending|Unknown"}
                  or
                  (
                    kube_pod_status_phase{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, phase="Running"} == 1
                    and on(namespace, pod, %(clusterLabel)s)
                    kube_pod_status_ready{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, condition="true"} == 0
                  )
                ) * on(namespace, pod, %(clusterLabel)s) group_left() topk by(namespace, pod, %(clusterLabel)s) (
                  1, max by(namespace, pod, owner_kind, %(clusterLabel)s) (kube_pod_owner{owner_kind!="Job"})
                )
              ) > 0
              unless on(namespace, pod, %(clusterLabel)s)
              kube_pod_status_reason{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, reason="SchedulingGated"} == 1
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Pod {{ $labels.namespace }}/{{ $labels.pod }} has been in a non-ready state for longer than 15 minutes%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Pod has been in a non-ready state for more than 15 minutes.',
            },
            'for': '15m',
            alert: 'KubePodNotReady',
          },
          {
            expr: |||
              kube_deployment_status_observed_generation{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                !=
              kube_deployment_metadata_generation{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Deployment generation for {{ $labels.namespace }}/{{ $labels.deployment }} does not match, this indicates that the Deployment has failed but has not been rolled back%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Deployment generation mismatch due to possible roll-back',
            },
            'for': '15m',
            alert: 'KubeDeploymentGenerationMismatch',
          },
          {
            expr: |||
              (
                kube_deployment_spec_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                  >
                kube_deployment_status_replicas_available{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
              ) and (
                changes(kube_deployment_status_replicas_updated{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}[10m])
                  ==
                0
              )
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has not matched the expected number of replicas for longer than 15 minutes%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Deployment has not matched the expected number of replicas.',
            },
            'for': '15m',
            alert: 'KubeDeploymentReplicasMismatch',
          },
          {
            expr: |||
              kube_deployment_status_condition{condition="Progressing", status="false",%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
              != 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Rollout of deployment {{ $labels.namespace }}/{{ $labels.deployment }} is not progressing for longer than 15 minutes%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Deployment rollout is not progressing.',
            },
            'for': '15m',
            alert: 'KubeDeploymentRolloutStuck',
          },
          {
            expr: |||
              (
                kube_statefulset_status_replicas_ready{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                  !=
                kube_statefulset_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
              ) and (
                changes(kube_statefulset_status_replicas_updated{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}[10m])
                  ==
                0
              )
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} has not matched the expected number of replicas for longer than 15 minutes%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'StatefulSet has not matched the expected number of replicas.',
            },
            'for': '15m',
            alert: 'KubeStatefulSetReplicasMismatch',
          },
          {
            expr: |||
              kube_statefulset_status_observed_generation{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                !=
              kube_statefulset_metadata_generation{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'StatefulSet generation for {{ $labels.namespace }}/{{ $labels.statefulset }} does not match, this indicates that the StatefulSet has failed but has not been rolled back%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'StatefulSet generation mismatch due to possible roll-back',
            },
            'for': '15m',
            alert: 'KubeStatefulSetGenerationMismatch',
          },
          {
            expr: |||
              (
                max by(namespace, statefulset, job, %(clusterLabel)s) (
                  kube_statefulset_status_current_revision{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                    unless
                  kube_statefulset_status_update_revision{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                )
                  * on(namespace, statefulset, job, %(clusterLabel)s)
                (
                  kube_statefulset_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                    !=
                  kube_statefulset_status_replicas_updated{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                )
              )  and on(namespace, statefulset, job, %(clusterLabel)s) (
                changes(kube_statefulset_status_replicas_updated{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}[5m])
                  ==
                0
              )
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} update has not been rolled out%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'StatefulSet update has not been rolled out.',
            },
            'for': '15m',
            alert: 'KubeStatefulSetUpdateNotRolledOut',
          },
          {
            alert: 'KubeDaemonSetRolloutStuck',
            expr: |||
              (
                (
                  kube_daemonset_status_current_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                    !=
                  kube_daemonset_status_desired_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                ) or (
                  kube_daemonset_status_number_misscheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                    !=
                  0
                ) or (
                  kube_daemonset_status_updated_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                    !=
                  kube_daemonset_status_desired_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                ) or (
                  kube_daemonset_status_number_available{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                    !=
                  kube_daemonset_status_desired_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                )
              ) and (
                changes(kube_daemonset_status_updated_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}[5m])
                  ==
                0
              )
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} has not finished or progressed for at least %s%s.' % [
                $._config.kubeDaemonSetRolloutStuckFor,
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'DaemonSet rollout is stuck.',
            },
            'for': $._config.kubeDaemonSetRolloutStuckFor,
          },
          {
            expr: |||
              kube_pod_container_status_waiting_reason{reason!="CrashLoopBackOff", %(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'pod/{{ $labels.pod }} in namespace {{ $labels.namespace }} on container {{ $labels.container}} has been in waiting state for longer than 1 hour. (reason: "{{ $labels.reason }}")%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Pod container waiting longer than 1 hour',
            },
            'for': '1h',
            alert: 'KubeContainerWaiting',
          },
          {
            alert: 'KubeDaemonSetNotScheduled',
            expr: |||
              kube_daemonset_status_desired_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                -
              kube_daemonset_status_current_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: '{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are not scheduled%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'DaemonSet pods are not scheduled.',
            },
            'for': '10m',
          },
          {
            alert: 'KubeDaemonSetMisScheduled',
            expr: |||
              kube_daemonset_status_number_misscheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: '{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are running where they are not supposed to run%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'DaemonSet pods are misscheduled.',
            },
            'for': '15m',
          },
          {
            alert: 'KubeJobNotCompleted',
            expr: |||
              time() - max by(namespace, job_name, %(clusterLabel)s) (kube_job_status_start_time{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                and
              kube_job_status_active{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} > 0) > %(kubeJobTimeoutDuration)s
                unless on(namespace, job_name, %(clusterLabel)s)
              max by(namespace, job_name, %(clusterLabel)s) (kube_job_labels{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s,%(kubeJobExcludedSelector)s} == 1)
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Job {{ $labels.namespace }}/{{ $labels.job_name }} is taking more than {{ "%s" | humanizeDuration }} to complete%s.' % [
                $._config.kubeJobTimeoutDuration,
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Job did not complete in time',
            },
          },
          {
            alert: 'KubeJobFailed',
            expr: |||
              kube_job_failed{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}  > 0
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Job {{ $labels.namespace }}/{{ $labels.job_name }} failed to complete. Removing failed job after investigation should clear this alert%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Job failed to complete.',
            },
          },
          {
            expr: |||
              (kube_horizontalpodautoscaler_status_desired_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                !=
              kube_horizontalpodautoscaler_status_current_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s})
                and
              (kube_horizontalpodautoscaler_status_current_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                >
              kube_horizontalpodautoscaler_spec_min_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s})
                and
              (kube_horizontalpodautoscaler_status_current_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                <
              kube_horizontalpodautoscaler_spec_max_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s})
                and
              changes(kube_horizontalpodautoscaler_status_current_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}[15m]) == 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler  }} has not matched the desired number of replicas for longer than 15 minutes%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'HPA has not matched desired number of replicas.',
            },
            'for': '15m',
            alert: 'KubeHpaReplicasMismatch',
          },
          {
            expr: |||
              (
                kube_horizontalpodautoscaler_status_current_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                  ==
                kube_horizontalpodautoscaler_spec_max_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
              )
              and on(namespace, horizontalpodautoscaler, %(clusterLabel)s) (
                kube_horizontalpodautoscaler_spec_max_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                  !=
                kube_horizontalpodautoscaler_spec_min_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
              )
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'HPA {{ $labels.namespace }}/{{ $labels.horizontalpodautoscaler  }} has been running at max replicas for longer than 15 minutes%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'HPA is running at max replicas',
            },
            'for': '15m',
            alert: 'KubeHpaMaxedOut',
          },
          {
            expr: |||
              (
                kube_poddisruptionbudget_status_desired_healthy{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                -
                kube_poddisruptionbudget_status_current_healthy{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
              )
              > 0
              and
              kube_poddisruptionbudget_status_expected_pods{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
              > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'PDB %s{{ $labels.namespace }}/{{ $labels.poddisruptionbudget }} expects {{ $value }} more healthy pods. The desired number of healthy pods has not been met for at least %s.' % [
                utils.ifShowMultiCluster($._config, '{{ $labels.%(clusterLabel)s }}/' % $._config),
                $._config.kubePdbNotEnoughHealthyPodsFor,
              ],
              summary: 'PDB does not have enough healthy pods.',
            },
            'for': $._config.kubePdbNotEnoughHealthyPodsFor,
            alert: 'KubePdbNotEnoughHealthyPods',
          },
        ],
      },
    ],
  },
}
