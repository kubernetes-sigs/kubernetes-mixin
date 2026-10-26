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
    cadvisorSelector: 'job="cadvisor"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
  },

  prometheusRules+:: {
    local additionalGrouping = utils.rejectGroupingLabels(
      $._config.additionalGrouping.recordingRules,
      ['__name__', 'endpoint', 'instance', 'job', 'job_name', 'phase', 'replicaset', 'service', 'workload', 'workload_type'],
      'application recording rules',
      'additionalGrouping.recordingRules'
    ),
    local groupingLabels(labels, excludedAdditionalLabels=[]) =
      utils.groupingLabels(labels, utils.withoutLabels(additionalGrouping, excludedAdditionalLabels)),
    local config = $._config {
      groupingClusterNamespacePodContainer: groupingLabels([$._config.clusterLabel, 'namespace', 'pod', 'container']),
      groupingClusterNamespacePod: groupingLabels([$._config.clusterLabel, 'namespace', 'pod']),
      groupingClusterNamespacePodNode: groupingLabels([$._config.clusterLabel, 'namespace', 'pod', 'node']),
      groupingNamespacePodCluster: groupingLabels(['namespace', 'pod', $._config.clusterLabel]),
      groupingNamespaceCluster: groupingLabels(['namespace', $._config.clusterLabel]),
      groupingNamespacePodContainerCluster: groupingLabels(['namespace', 'pod', 'container', $._config.clusterLabel]),
      groupingClusterNamespaceWorkloadPod: groupingLabels([$._config.clusterLabel, 'namespace', 'workload', 'pod']),
      groupingClusterReplicasetNamespace: groupingLabels([$._config.clusterLabel, 'replicaset', 'namespace']),
      groupingReplicasetNamespaceCluster: groupingLabels(['replicaset', 'namespace', $._config.clusterLabel]),
      groupingClusterNamespaceJobNamePodOwnerName: groupingLabels([$._config.clusterLabel, 'namespace', 'job_name', 'pod', 'owner_name']),
      groupingClusterNamespaceWorkloadWorkloadTypePod: groupingLabels([$._config.clusterLabel, 'namespace', 'workload', 'workload_type', 'pod']),
      groupingClusterNamespaceJobNamePod: groupingLabels([$._config.clusterLabel, 'namespace', 'job_name', 'pod']),
      groupingClusterNamespaceReplicaset: groupingLabels([$._config.clusterLabel, 'namespace', 'replicaset']),
      groupingClusterNamespacePodOwnerNameOwnerKind: groupingLabels([$._config.clusterLabel, 'namespace', 'pod', 'owner_name', 'owner_kind']),
      matchingClusterNamespacePod: groupingLabels([$._config.clusterLabel, 'namespace', 'pod'], ['container', 'image', 'node']),
      matchingNamespacePodCluster: groupingLabels(['namespace', 'pod', $._config.clusterLabel], ['container', 'node', 'phase', 'resource', 'unit']),
      matchingClusterReplicasetNamespace: groupingLabels([$._config.clusterLabel, 'replicaset', 'namespace'], ['owner_kind', 'owner_name', 'pod']),
      matchingReplicasetNamespaceCluster: groupingLabels(['replicaset', 'namespace', $._config.clusterLabel], ['owner_kind', 'owner_name', 'pod']),
      matchingClusterNamespaceJobName: groupingLabels([$._config.clusterLabel, 'namespace', 'job_name'], ['owner_kind', 'owner_name', 'pod']),
      matchingClusterNamespaceReplicaset: groupingLabels([$._config.clusterLabel, 'namespace', 'replicaset'], ['owner_kind', 'owner_name', 'pod']),
      ownerGroupingClusterReplicasetNamespaceOwnerName: groupingLabels([$._config.clusterLabel, 'replicaset', 'namespace', 'owner_name'], ['pod']),
      ownerGroupingClusterNamespaceJobNameOwnerKindOwnerName: groupingLabels([$._config.clusterLabel, 'namespace', 'job_name', 'owner_kind', 'owner_name'], ['pod']),
      ownerGroupingClusterNamespaceReplicasetOwnerKindOwnerName: groupingLabels([$._config.clusterLabel, 'namespace', 'replicaset', 'owner_kind', 'owner_name'], ['pod']),
    },

    groups+: [
      {
        name: 'k8s.rules.container_cpu_usage_seconds_total',
        rules: [
          {
            // Reduces cardinality of this timeseries by #cores, which makes it
            // more useable in dashboards.  Also, allows us to do things like
            // quantile_over_time(...) which would otherwise not be possible.
            record: 'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m',
            expr: |||
              sum by (%(groupingClusterNamespacePodContainer)s) (
                rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!=""}[5m])
              ) * on (%(matchingClusterNamespacePod)s) group_left(node) topk by (%(matchingClusterNamespacePod)s) (
                1, max by(%(groupingClusterNamespacePodNode)s) (kube_pod_info{node!=""})
              )
            ||| % config,
          },
          {
            record: 'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate',
            expr: |||
              sum by (%(groupingClusterNamespacePodContainer)s) (
                irate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!=""}[5m])
              ) * on (%(matchingClusterNamespacePod)s) group_left(node) topk by (%(matchingClusterNamespacePod)s) (
                1, max by(%(groupingClusterNamespacePodNode)s) (kube_pod_info{node!=""})
              )
            ||| % config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_working_set_bytes',
        rules: [
          {
            record: 'node_namespace_pod_container:container_memory_working_set_bytes',
            expr: |||
              container_memory_working_set_bytes{%(cadvisorSelector)s, image!=""}
              * on (%(matchingClusterNamespacePod)s) group_left(node) topk by(%(matchingClusterNamespacePod)s) (1,
                max by(%(groupingClusterNamespacePodNode)s) (kube_pod_info{node!=""})
              )
            ||| % config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_rss',
        rules: [
          {
            record: 'node_namespace_pod_container:container_memory_rss',
            expr: |||
              container_memory_rss{%(cadvisorSelector)s, image!=""}
              * on (%(matchingClusterNamespacePod)s) group_left(node) topk by(%(matchingClusterNamespacePod)s) (1,
                max by(%(groupingClusterNamespacePodNode)s) (kube_pod_info{node!=""})
              )
            ||| % config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_cache',
        rules: [
          {
            record: 'node_namespace_pod_container:container_memory_cache',
            expr: |||
              container_memory_cache{%(cadvisorSelector)s, image!=""}
              * on (%(matchingClusterNamespacePod)s) group_left(node) topk by(%(matchingClusterNamespacePod)s) (1,
                max by(%(groupingClusterNamespacePodNode)s) (kube_pod_info{node!=""})
              )
            ||| % config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_swap',
        rules: [
          {
            record: 'node_namespace_pod_container:container_memory_swap',
            expr: |||
              container_memory_swap{%(cadvisorSelector)s, image!=""}
              * on (%(matchingClusterNamespacePod)s) group_left(node) topk by(%(matchingClusterNamespacePod)s) (1,
                max by(%(groupingClusterNamespacePodNode)s) (kube_pod_info{node!=""})
              )
            ||| % config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_requests',
        rules: [
          {
            record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_requests',
            expr: |||
              kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s}  * on (%(matchingNamespacePodCluster)s)
              group_left() max by (%(groupingNamespacePodCluster)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % config,
          },
          {
            record: 'namespace_memory:kube_pod_container_resource_requests:sum',
            expr: |||
              sum by (%(groupingNamespaceCluster)s) (
                  sum by (%(groupingNamespacePodCluster)s) (
                      max by (%(groupingNamespacePodContainerCluster)s) (
                        kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s}
                      ) * on(%(matchingNamespacePodCluster)s) group_left() max by (%(groupingNamespacePodCluster)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_cpu_requests',
        rules: [
          {
            record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests',
            expr: |||
              kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s}  * on (%(matchingNamespacePodCluster)s)
              group_left() max by (%(groupingNamespacePodCluster)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % config,
          },
          {
            record: 'namespace_cpu:kube_pod_container_resource_requests:sum',
            expr: |||
              sum by (%(groupingNamespaceCluster)s) (
                  sum by (%(groupingNamespacePodCluster)s) (
                      max by (%(groupingNamespacePodContainerCluster)s) (
                        kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s}
                      ) * on(%(matchingNamespacePodCluster)s) group_left() max by (%(groupingNamespacePodCluster)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_limits',
        rules: [
          {
            record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_limits',
            expr: |||
              kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s}  * on (%(matchingNamespacePodCluster)s)
              group_left() max by (%(groupingNamespacePodCluster)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % config,
          },
          {
            record: 'namespace_memory:kube_pod_container_resource_limits:sum',
            expr: |||
              sum by (%(groupingNamespaceCluster)s) (
                  sum by (%(groupingNamespacePodCluster)s) (
                      max by (%(groupingNamespacePodContainerCluster)s) (
                        kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s}
                      ) * on(%(matchingNamespacePodCluster)s) group_left() max by (%(groupingNamespacePodCluster)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_cpu_limits',
        rules: [
          {
            record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits',
            expr: |||
              kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s}  * on (%(matchingNamespacePodCluster)s)
              group_left() max by (%(groupingNamespacePodCluster)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % config,
          },
          {
            record: 'namespace_cpu:kube_pod_container_resource_limits:sum',
            expr: |||
              sum by (%(groupingNamespaceCluster)s) (
                  sum by (%(groupingNamespacePodCluster)s) (
                      max by (%(groupingNamespacePodContainerCluster)s) (
                        kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s}
                      ) * on(%(matchingNamespacePodCluster)s) group_left() max by (%(groupingNamespacePodCluster)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % config,
          },
        ],
      },
      {
        name: 'k8s.rules.pod_owner',
        rules: [
          // workload aggregation for replicasets
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(groupingClusterNamespaceWorkloadPod)s) (
                label_replace(
                  label_replace(
                    kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet"},
                    "replicaset", "$1", "owner_name", "(.*)"
                  ) * on (%(matchingClusterReplicasetNamespace)s) group_left(owner_name) topk by(%(matchingClusterReplicasetNamespace)s) (
                    1, max by (%(ownerGroupingClusterReplicasetNamespaceOwnerName)s) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind=""}
                    )
                  ),
                  "workload", "$1", "replicaset", "(.*)"
                )
              )
            ||| % config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'ReplicaSet' else 'replicaset',
            },
          },
          // workload aggregation for deployments
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(groupingClusterNamespaceWorkloadPod)s) (
                label_replace(
                  label_replace(
                    kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet"},
                    "replicaset", "$1", "owner_name", "(.*)"
                  ) * on(%(matchingReplicasetNamespaceCluster)s) group_left(owner_name) topk by(%(matchingClusterReplicasetNamespace)s) (
                    1, max by (%(ownerGroupingClusterReplicasetNamespaceOwnerName)s) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind="Deployment"}
                    )
                  ),
                  "workload", "$1", "owner_name", "(.*)"
                )
              )
            ||| % config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'Deployment' else 'deployment',
            },
          },
          // workload aggregation for daemonsets
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(groupingClusterNamespaceWorkloadPod)s) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="DaemonSet"},
                  "workload", "$1", "owner_name", "(.*)"
                )
              )
            ||| % config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'DaemonSet' else 'daemonset',
            },
          },
          // workload aggregation for statefulsets
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(groupingClusterNamespaceWorkloadPod)s) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="StatefulSet"},
                "workload", "$1", "owner_name", "(.*)")
              )
            ||| % config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'StatefulSet' else 'statefulset',
            },
          },
          // backwards compatibility for jobs
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              group by (%(groupingClusterNamespaceWorkloadPod)s) (
                label_join(
                  group by (%(groupingClusterNamespaceJobNamePodOwnerName)s) (
                    label_join(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job"}
                    , "job_name", "", "owner_name")
                  )
                  * on (%(matchingClusterNamespaceJobName)s) group_left()
                  group by (%(matchingClusterNamespaceJobName)s) (
                    kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind=~"Pod|"}
                  )
                , "workload", "", "owner_name")
              )
            ||| % config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'Job' else 'job',
            },
          },
          // workload aggregation for barepods
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(groupingClusterNamespaceWorkloadPod)s) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="", owner_name=""},
                "workload", "$1", "pod", "(.+)")
              )
            ||| % config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'BarePod' else 'barepod',
            },
          },
          // workload aggregation for staticpods
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(groupingClusterNamespaceWorkloadPod)s) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Node"},
                "workload", "$1", "pod", "(.+)")
              )
            ||| % config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'StaticPod' else 'staticpod',
            },
          },
          // workload aggregation for non-standard types (jobs, replicasets)
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              group by (%(groupingClusterNamespaceWorkloadWorkloadTypePod)s) (
                label_join(
                  label_join(
                    group by (%(groupingClusterNamespaceJobNamePod)s) (
                      label_join(
                        kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job"}
                      , "job_name", "", "owner_name")
                    )
                    * on (%(matchingClusterNamespaceJobName)s) group_left(owner_kind, owner_name)
                    group by (%(ownerGroupingClusterNamespaceJobNameOwnerKindOwnerName)s) (
                      kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind!="Pod", owner_kind!=""}
                    )
                  , "workload", "", "owner_name")
                , "workload_type", "", "owner_kind")

                OR

                label_replace(
                  label_replace(
                    label_replace(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet"}
                      , "replicaset", "$1", "owner_name", "(.+)"
                    )
                    * on(%(matchingClusterNamespaceReplicaset)s) group_left(owner_kind, owner_name)
                    group by (%(ownerGroupingClusterNamespaceReplicasetOwnerKindOwnerName)s) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind!="Deployment", owner_kind!=""}
                    )
                  , "workload", "$1", "owner_name", "(.+)")
                  OR
                  label_replace(
                    group by (%(groupingClusterNamespacePodOwnerNameOwnerKind)s) (
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind!="ReplicaSet", owner_kind!="DaemonSet", owner_kind!="StatefulSet", owner_kind!="Job", owner_kind!="Node", owner_kind!=""}
                    )
                    , "workload", "$1", "owner_name", "(.+)"
                  )
                , "workload_type", "$1", "owner_kind", "(.+)")
              )
            ||| % config,
          },
        ],
      },
    ],
  },
}
