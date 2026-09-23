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
  _config+:: {
    cadvisorSelector: 'job="cadvisor"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
  },

  prometheusRules+:: {
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
              sum by (%(clusterLabel)s, namespace, pod, container) (
                rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!=""}[5m])
              ) * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by (%(clusterLabel)s, namespace, pod) (
                1, max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
          },
          {
            record: 'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate',
            expr: |||
              sum by (%(clusterLabel)s, namespace, pod, container) (
                irate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!=""}[5m])
              ) * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by (%(clusterLabel)s, namespace, pod) (
                1, max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
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
              * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by(%(clusterLabel)s, namespace, pod) (1,
                max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
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
              * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by(%(clusterLabel)s, namespace, pod) (1,
                max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
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
              * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by(%(clusterLabel)s, namespace, pod) (1,
                max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
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
              * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by(%(clusterLabel)s, namespace, pod) (1,
                max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_requests',
        rules: [
          {
            record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_requests',
            expr: |||
              kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s}  * on (namespace, pod, %(clusterLabel)s)
              group_left() max by (namespace, pod, %(clusterLabel)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % $._config,
          },
          {
            record: 'namespace_memory:kube_pod_container_resource_requests:sum',
            expr: |||
              sum by (namespace, %(clusterLabel)s) (
                  sum by (namespace, pod, %(clusterLabel)s) (
                      max by (namespace, pod, container, %(clusterLabel)s) (
                        kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s}
                      ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_cpu_requests',
        rules: [
          {
            record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests',
            expr: |||
              kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s}  * on (namespace, pod, %(clusterLabel)s)
              group_left() max by (namespace, pod, %(clusterLabel)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % $._config,
          },
          {
            record: 'namespace_cpu:kube_pod_container_resource_requests:sum',
            expr: |||
              sum by (namespace, %(clusterLabel)s) (
                  sum by (namespace, pod, %(clusterLabel)s) (
                      max by (namespace, pod, container, %(clusterLabel)s) (
                        kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s}
                      ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_limits',
        rules: [
          {
            record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_limits',
            expr: |||
              kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s}  * on (namespace, pod, %(clusterLabel)s)
              group_left() max by (namespace, pod, %(clusterLabel)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % $._config,
          },
          {
            record: 'namespace_memory:kube_pod_container_resource_limits:sum',
            expr: |||
              sum by (namespace, %(clusterLabel)s) (
                  sum by (namespace, pod, %(clusterLabel)s) (
                      max by (namespace, pod, container, %(clusterLabel)s) (
                        kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s}
                      ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_cpu_limits',
        rules: [
          {
            record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits',
            expr: |||
              kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s}  * on (namespace, pod, %(clusterLabel)s)
              group_left() max by (namespace, pod, %(clusterLabel)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % $._config,
          },
          {
            record: 'namespace_cpu:kube_pod_container_resource_limits:sum',
            expr: |||
              sum by (namespace, %(clusterLabel)s) (
                  sum by (namespace, pod, %(clusterLabel)s) (
                      max by (namespace, pod, container, %(clusterLabel)s) (
                        kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s}
                      ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % $._config,
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
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  label_replace(
                    kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet"},
                    "replicaset", "$1", "owner_name", "(.*)"
                  ) * on (%(clusterLabel)s, replicaset, namespace) group_left(owner_name) topk by(%(clusterLabel)s, replicaset, namespace) (
                    1, max by (%(clusterLabel)s, replicaset, namespace, owner_name) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind=""}
                    )
                  ),
                  "workload", "$1", "replicaset", "(.*)"
                )
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'ReplicaSet' else 'replicaset',
            },
          },
          // workload aggregation for deployments
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  label_replace(
                    kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet"},
                    "replicaset", "$1", "owner_name", "(.*)"
                  ) * on(replicaset, namespace, %(clusterLabel)s) group_left(owner_name) topk by(%(clusterLabel)s, replicaset, namespace) (
                    1, max by (%(clusterLabel)s, replicaset, namespace, owner_name) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind="Deployment"}
                    )
                  ),
                  "workload", "$1", "owner_name", "(.*)"
                )
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'Deployment' else 'deployment',
            },
          },
          // workload aggregation for daemonsets
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="DaemonSet"},
                  "workload", "$1", "owner_name", "(.*)"
                )
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'DaemonSet' else 'daemonset',
            },
          },
          // workload aggregation for statefulsets
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="StatefulSet"},
                "workload", "$1", "owner_name", "(.*)")
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'StatefulSet' else 'statefulset',
            },
          },
          // backwards compatibility for jobs
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              group by (%(clusterLabel)s, namespace, workload, pod) (
                label_join(
                  group by (%(clusterLabel)s, namespace, job_name, pod, owner_name) (
                    label_join(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job"}
                    , "job_name", "", "owner_name")
                  )
                  * on (%(clusterLabel)s, namespace, job_name) group_left()
                  group by (%(clusterLabel)s, namespace, job_name) (
                    kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind=~"Pod|"}
                  )
                , "workload", "", "owner_name")
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'Job' else 'job',
            },
          },
          // workload aggregation for barepods
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="", owner_name=""},
                "workload", "$1", "pod", "(.+)")
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'BarePod' else 'barepod',
            },
          },
          // workload aggregation for staticpods
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Node"},
                "workload", "$1", "pod", "(.+)")
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'StaticPod' else 'staticpod',
            },
          },
          // workload aggregation for non-standard types (jobs, replicasets)
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              group by (%(clusterLabel)s, namespace, workload, workload_type, pod) (
                label_join(
                  label_join(
                    group by (%(clusterLabel)s, namespace, job_name, pod) (
                      label_join(
                        kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job"}
                      , "job_name", "", "owner_name")
                    )
                    * on (%(clusterLabel)s, namespace, job_name) group_left(owner_kind, owner_name)
                    group by (%(clusterLabel)s, namespace, job_name, owner_kind, owner_name) (
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
                    * on(%(clusterLabel)s, namespace, replicaset) group_left(owner_kind, owner_name)
                    group by (%(clusterLabel)s, namespace, replicaset, owner_kind, owner_name) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind!="Deployment", owner_kind!=""}
                    )
                  , "workload", "$1", "owner_name", "(.+)")
                  OR
                  label_replace(
                    group by (%(clusterLabel)s, namespace, pod, owner_name, owner_kind) (
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind!="ReplicaSet", owner_kind!="DaemonSet", owner_kind!="StatefulSet", owner_kind!="Job", owner_kind!="Node", owner_kind!=""}
                    )
                    , "workload", "$1", "owner_name", "(.+)"
                  )
                , "workload_type", "$1", "owner_kind", "(.+)")
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.workload',
        local pascalCaseWorkloadTypes = {
          barePod: 'BarePod',
          daemonSet: 'DaemonSet',
          deployment: 'Deployment',
          job: 'Job',
          pod: 'Pod',
          replicaSet: 'ReplicaSet',
          statefulSet: 'StatefulSet',
          staticPod: 'StaticPod',
        },
        local downcaseWorkloadTypes = {
          barePod: 'barepod',
          daemonSet: 'daemonset',
          deployment: 'deployment',
          job: 'job',
          pod: 'pod',
          replicaSet: 'replicaset',
          statefulSet: 'statefulset',
          staticPod: 'staticpod',
        },
        local workloadTypes = (
          if $._config.usePascalCaseForWorkloadTypeLabelValues then
            pascalCaseWorkloadTypes
          else
            downcaseWorkloadTypes
        ),
        local knownManagedPodOwnerMatchers = '%(daemonSet)s|%(deployment)s|%(job)s|%(replicaSet)s|%(statefulSet)s' % pascalCaseWorkloadTypes,
        local knownManagedJobOwnerMatchers = '%(pod)s' % pascalCaseWorkloadTypes,
        local podsForWorkload(podMetricExpr, extraGroupLabels, workloadExpr, dynamicWorkloadType=false) = (
          |||
            sum by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_is_controller%(workloadTypeLabel)s%(extraGroupLabels)s) (
              (%(podMetricExpr)s)
              * on (%(clusterLabel)s, %(namespaceLabel)s, pod) group_left (workload, workload_is_controller%(workloadTypeLabel)s)
              topk by (%(clusterLabel)s, %(namespaceLabel)s, pod) (
                1,
                (%(workloadExpr)s)
              )
            )
          ||| % ($._config {
                   extraGroupLabels: extraGroupLabels,
                   podMetricExpr: podMetricExpr,
                   workloadExpr: workloadExpr,
                   workloadTypeLabel: if dynamicWorkloadType then ', workload_type' else '',
                 })
        ),
        local fixedPodWorkloadTypes = [
          workloadTypes.daemonSet,
          workloadTypes.deployment,
          workloadTypes.job,
          workloadTypes.pod,
          workloadTypes.replicaSet,
          workloadTypes.statefulSet,
          workloadTypes.barePod,
          workloadTypes.staticPod,
        ],
        local podWorkloadExprs = [
          // DaemonSet
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_is_controller) (
              label_replace(
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="DaemonSet", owner_is_controller="true"},
                  "workload", "$1", "owner_name", "(.+)"
                ),
                "workload_is_controller", "$1", "owner_is_controller", "(.+)"
              )
            )
          ||| % $._config,
          // Deployment
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_is_controller) (
              label_replace(
                label_replace(
                  max by (%(clusterLabel)s, %(namespaceLabel)s, pod, replicaset, owner_is_controller) (
                    label_replace(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet", owner_is_controller="true"},
                      "replicaset", "$1", "owner_name", "(.+)"
                    )
                  )
                  * on (%(clusterLabel)s, %(namespaceLabel)s, replicaset, owner_is_controller) group_left (owner_name)
                  topk by (%(clusterLabel)s, %(namespaceLabel)s, replicaset, owner_is_controller) (
                    1,
                    max by (%(clusterLabel)s, %(namespaceLabel)s, replicaset, owner_name, owner_is_controller) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind="Deployment", owner_is_controller="true"}
                    )
                  ),
                  "workload", "$1", "owner_name", "(.+)"
                ),
                "workload_is_controller", "$1", "owner_is_controller", "(.+)"
              )
            )
          ||| % $._config,
          // Job (Bare/StandAlone)
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_is_controller) (
              label_replace(
                label_replace(
                  max by (%(clusterLabel)s, %(namespaceLabel)s, pod, job_name, owner_is_controller) (
                    label_replace(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job", owner_is_controller="true"},
                      "job_name", "$1", "owner_name", "(.+)"
                    )
                  )
                  * on (%(clusterLabel)s, %(namespaceLabel)s, job_name) group_left ()
                  max by (%(clusterLabel)s, %(namespaceLabel)s, job_name) (
                    kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind=""}
                    OR
                    (
                      kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind!=""}
                      unless on (%(clusterLabel)s, %(namespaceLabel)s, job_name)
                      kube_job_owner{%(kubeStateMetricsSelector)s, owner_is_controller="true"}
                    )
                  ),
                  "workload", "$1", "job_name", "(.+)"
                ),
                "workload_is_controller", "$1", "owner_is_controller", "(.+)"
              )
            )
          ||| % $._config,
          // Job (owned by Pod)
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_is_controller) (
              label_replace(
                label_replace(
                  max by (%(clusterLabel)s, %(namespaceLabel)s, pod, job_name, owner_is_controller) (
                    label_replace(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job", owner_is_controller="true"},
                      "job_name", "$1", "owner_name", "(.+)"
                    )
                  )
                  * on (%(clusterLabel)s, %(namespaceLabel)s, job_name, owner_is_controller) group_left (owner_name)
                  topk by (%(clusterLabel)s, %(namespaceLabel)s, job_name) (
                    1,
                    max by (%(clusterLabel)s, %(namespaceLabel)s, job_name, owner_name, owner_is_controller) (
                      kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind="Pod", owner_is_controller="true"}
                    )
                  ),
                  "workload", "$1", "owner_name", "(.+)"
                ),
                "workload_is_controller", "$1", "owner_is_controller", "(.+)"
              )
            )
          ||| % $._config,
          // ReplicaSet (Bare/StandAlone)
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_is_controller) (
              label_replace(
                label_replace(
                  max by (%(clusterLabel)s, %(namespaceLabel)s, pod, replicaset, owner_is_controller) (
                    label_replace(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet", owner_is_controller="true"},
                      "replicaset", "$1", "owner_name", "(.+)"
                    )
                  )
                  * on (%(clusterLabel)s, %(namespaceLabel)s, replicaset) group_left ()
                  max by (%(clusterLabel)s, %(namespaceLabel)s, replicaset) (
                    kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind=""}
                  ),
                  "workload", "$1", "replicaset", "(.+)"
                ),
                "workload_is_controller", "$1", "owner_is_controller", "(.+)"
              )
            )
          ||| % $._config,
          // StatefulSet
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_is_controller) (
              label_replace(
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="StatefulSet", owner_is_controller="true"},
                  "workload", "$1", "owner_name", "(.+)"
                ),
                "workload_is_controller", "$1", "owner_is_controller", "(.+)"
              )
            )
          ||| % $._config,
          // Bare Pod
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_is_controller) (
              label_replace(
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="", owner_name=""},
                  "workload", "$1", "pod", "(.+)"
                ),
                "workload_is_controller", "true", "", ""
              )
            )
          ||| % $._config,
          // Static Pod
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_is_controller) (
              label_replace(
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Node", owner_is_controller="true"},
                  "workload", "$1", "pod", "(.+)"
                ),
                "workload_is_controller", "$1", "owner_is_controller", "(.+)"
              )
            )
          ||| % $._config,
          // Custom ReplicaSet controller
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_type, workload_is_controller) (
              label_replace(
                label_replace(label_replace(
                  max by (%(clusterLabel)s, %(namespaceLabel)s, pod, replicaset) (
                    label_replace(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet", owner_is_controller="true"},
                      "replicaset", "$1", "owner_name", "(.+)"
                    )
                  )
                  * on (%(clusterLabel)s, %(namespaceLabel)s, replicaset) group_left (owner_kind, owner_name, owner_is_controller)
                  topk by (%(clusterLabel)s, %(namespaceLabel)s, replicaset, owner_kind, owner_name, owner_is_controller) (
                    1,
                    max by (%(clusterLabel)s, %(namespaceLabel)s, replicaset, owner_kind, owner_name, owner_is_controller) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind!="Deployment", owner_kind!="", owner_is_controller="true"}
                    )
                  ),
                  "workload", "$1", "owner_name", "(.+)"),
                "workload_type", "$1", "owner_kind", "(.+)"),
                "workload_is_controller", "$1", "owner_is_controller", "(.+)"
              )
            )
          ||| % $._config,
          // Custom direct Pod controller
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_type, workload_is_controller) (
              label_replace(
                label_replace(label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind!~"ReplicaSet|DaemonSet|StatefulSet|Job|Node", owner_kind!="", owner_is_controller="true"},
                  "workload", "$1", "owner_name", "(.+)"),
                "workload_type", "$1", "owner_kind", "(.+)"),
                "workload_is_controller", "$1", "owner_is_controller", "(.+)"
              )
            )
          ||| % $._config,
          // Custom Job controller (including CronJob)
          |||
            max by (%(clusterLabel)s, %(namespaceLabel)s, pod, workload, workload_type, workload_is_controller) (
              label_replace(
                label_replace(label_replace(
                  max by (%(clusterLabel)s, %(namespaceLabel)s, pod, job_name) (
                    label_replace(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job", owner_is_controller="true"},
                      "job_name", "$1", "owner_name", "(.+)"
                    )
                  )
                  * on (%(clusterLabel)s, %(namespaceLabel)s, job_name) group_left (owner_kind, owner_name, owner_is_controller)
                  topk by (%(clusterLabel)s, %(namespaceLabel)s, job_name, owner_is_controller) (
                    1,
                    max by (%(clusterLabel)s, %(namespaceLabel)s, job_name, owner_kind, owner_name, owner_is_controller) (
                      kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind!~"%(knownManagedJobOwnerMatchers)s", owner_kind!="", owner_is_controller="true"}
                    )
                  ),
                  "workload", "$1", "owner_name", "(.+)"),
                "workload_type", "$1", "owner_kind", "(.+)"),
                "workload_is_controller", "$1", "owner_is_controller", "(.+)"
              )
            )
          ||| % ($._config { knownManagedJobOwnerMatchers: knownManagedJobOwnerMatchers }),
        ],
        local customPodWorkloadExpr = std.join('\nOR\n', [podWorkloadExprs[i] for i in std.range(8, 10)]),
        local readyPodMetricExpr = |||
          max by (%(clusterLabel)s, %(namespaceLabel)s, pod) (
            kube_pod_status_ready{%(kubeStateMetricsSelector)s, condition="true"}
          )
        ||| % $._config,
        local phasePodMetricExpr = |||
          max by (%(clusterLabel)s, %(namespaceLabel)s, pod, phase) (
            kube_pod_status_phase{%(kubeStateMetricsSelector)s}
          )
        ||| % $._config,
        rules: [
          {
            record: 'namespace_workload:kube_pod_owner:derived',
            expr: (
              |||
                max by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_is_controller) (%(workloadExpr)s)
              ||| % (
                $._config {
                  workloadExpr: podWorkloadExprs[i],
                }
              )
            ),
            labels: {
              workload_type: fixedPodWorkloadTypes[i],
            },
          }
          for i in std.range(0, std.length(fixedPodWorkloadTypes) - 1)
        ] + [
          {
            record: 'namespace_workload:kube_pod_owner:derived',
            expr: (
              |||
                max by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type, workload_is_controller) (%(workloadExpr)s)
              ||| % (
                $._config {
                  workloadExpr: customPodWorkloadExpr,
                }
              )
            ),
          },
        ] + [
          {
            record: 'namespace_workload:kube_pods_ready:sum',
            expr: podsForWorkload(readyPodMetricExpr, '', podWorkloadExprs[i]),
            labels: {
              workload_type: fixedPodWorkloadTypes[i],
            },
          }
          for i in std.range(0, std.length(fixedPodWorkloadTypes) - 1)
        ] + [
          {
            record: 'namespace_workload:kube_pods_ready:sum',
            expr: podsForWorkload(readyPodMetricExpr, '', customPodWorkloadExpr, true),
          },
        ] + [
          {
            record: 'namespace_workload:kube_pods_phase:sum',
            expr: podsForWorkload(phasePodMetricExpr, ', phase', podWorkloadExprs[i]),
            labels: {
              workload_type: fixedPodWorkloadTypes[i],
            },
          }
          for i in std.range(0, std.length(fixedPodWorkloadTypes) - 1)
        ] + [
          {
            record: 'namespace_workload:kube_pods_phase:sum',
            expr: podsForWorkload(phasePodMetricExpr, ', phase', customPodWorkloadExpr, true),
          },
        ] + [
          {
            // There are a few cases that kube_pods_desired cannot really cover:
            // * Custom Workloads (such as Rollouts, ...) as we do not know which metric would include the desired number of Pods.
            // * Bare Pods, mostly because the desired number would always be 1
            // * Static Pods, mostly because the desired number would always be 1
            // * Pod owned Jobs (might own multiple Jobs)
            record: 'namespace_workload:kube_pods_desired:sum',
            expr: (
              |||
                topk by(%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type)
                 (1, sum by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                   label_replace(label_replace(
                     topk by(%(clusterLabel)s, %(namespaceLabel)s, %(workloadLabel)s)
                       (1, (%(workloadMetricQuery)s)),
                     "workload", "$1", "%(workloadLabel)s", "(.+)"),
                   "workload_type", "%(workloadType)s", "", ""))) %(noOwnerExpr)s
              |||
            ) % ($._config {
                   ownershipCheckMetric: '',
                   ownershipCheckAdditionalSelectors: '',
                 } + metricTuple + {
                   noOwnerExpr: (if self.ownershipCheckMetric == '' then '' else (
                                   |||
                                     and on (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type)
                                     topk(1,
                                       label_replace(label_replace(%(ownershipCheckMetric)s{%(kubeStateMetricsSelector)s%(ownershipCheckAdditionalSelectors)s},
                                         "workload", "$1", "%(workloadLabel)s", "(.+)"),
                                       "workload_type", "%(workloadType)s", "", ""))
                                   ||| % self
                                 )),
                 }),
            labels: {
              workload_type: metricTuple.workloadType,
            },
          }
          for metricTuple in [
            {
              workloadMetricQuery: 'kube_daemonset_status_desired_number_scheduled',
              workloadLabel: 'daemonset',
              workloadType: workloadTypes.daemonSet,
            },
            {
              workloadMetric: 'kube_deployment_spec_replicas',
              workloadMetricQuery: (
                |||
                  max by(%(clusterLabel)s, %(namespaceLabel)s, deployment) (
                    label_replace(kube_deployment_spec_replicas{%(kubeStateMetricsSelector)s}, "deployment_original", "true", "", "")
                    or
                    label_replace(
                      (
                        kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind="Deployment"}
                        * on(%(clusterLabel)s, %(namespaceLabel)s, replicaset) group_left()
                        kube_replicaset_spec_replicas{%(kubeStateMetricsSelector)s}
                      ),
                      "deployment", "$1", "owner_name", "(.+)"
                    )
                  )
                ||| % $._config
              ),
              workloadLabel: 'deployment',
              workloadType: workloadTypes.deployment,
            },
            {
              workloadMetricQuery: 'kube_replicaset_spec_replicas',
              ownershipCheckMetric: 'kube_replicaset_owner',
              ownershipCheckAdditionalSelectors: ', owner_kind=""',
              workloadLabel: 'replicaset',
              workloadType: workloadTypes.replicaSet,
            },
            {
              workloadMetricQuery: 'kube_statefulset_replicas',
              workloadLabel: 'statefulset',
              workloadType: workloadTypes.statefulSet,
            },
          ]
        ],
      },
    ],
  },
}
