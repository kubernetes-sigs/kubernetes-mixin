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
                    kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet", owner_is_controller="true"},
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
                    kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet", owner_is_controller="true"},
                    "replicaset", "$1", "owner_name", "(.*)"
                  ) * on(replicaset, namespace, %(clusterLabel)s) group_left(owner_name) topk by(%(clusterLabel)s, replicaset, namespace) (
                    1, max by (%(clusterLabel)s, replicaset, namespace, owner_name) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind="Deployment", owner_is_controller="true"}
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
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="DaemonSet", owner_is_controller="true"},
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
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="StatefulSet", owner_is_controller="true"},
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
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job", owner_is_controller="true"}
                    , "job_name", "", "owner_name")
                  )
                  * on (%(clusterLabel)s, namespace, job_name) group_left()
                  (
                    group by (%(clusterLabel)s, namespace, job_name) (
                      kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind="Pod", owner_is_controller="true"}
                    )
                    OR
                    group by (%(clusterLabel)s, namespace, job_name) (
                      kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind="", owner_is_controller=""}
                    )
                    OR
                    group by (%(clusterLabel)s, namespace, job_name) (
                      kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind!=""} unless on(%(clusterLabel)s, namespace, job_name) kube_job_owner{%(kubeStateMetricsSelector)s, owner_is_controller="true"}
                    )
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
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Node", owner_is_controller="true"},
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
                        kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job", owner_is_controller="true"}
                      , "job_name", "", "owner_name")
                    )
                    * on (%(clusterLabel)s, namespace, job_name) group_left(owner_kind, owner_name)
                    group by (%(clusterLabel)s, namespace, job_name, owner_kind, owner_name) (
                      kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind!="Pod", owner_kind!="", owner_is_controller="true"}
                    )
                  , "workload", "", "owner_name")
                , "workload_type", "", "owner_kind")

                OR

                label_replace(
                  label_replace(
                    label_replace(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet", owner_is_controller="true"}
                      , "replicaset", "$1", "owner_name", "(.+)"
                    )
                    * on(%(clusterLabel)s, namespace, replicaset) group_left(owner_kind, owner_name)
                    group by (%(clusterLabel)s, namespace, replicaset, owner_kind, owner_name) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind!="Deployment", owner_kind!="", owner_is_controller="true"}
                    )
                  , "workload", "$1", "owner_name", "(.+)")
                  OR
                  label_replace(
                    group by (%(clusterLabel)s, namespace, pod, owner_name, owner_kind) (
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind!="ReplicaSet", owner_kind!="DaemonSet", owner_kind!="StatefulSet", owner_kind!="Job", owner_kind!="Node", owner_kind!="", owner_is_controller="true"}
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
          barePod: "BarePod",
          daemonSet: "DaemonSet",
          deployment: "Deployment",
          job: "Job",
          pod: "Pod",
          replicaSet: "ReplicaSet",
          statefulSet: "StatefulSet",
          staticPod: "StaticPod",
        },
        local downcaseWorkloadTypes = {
          barePod: "barepod",
          daemonSet: "daemonset",
          deployment: "deployment",
          job: "job",
          pod: "pod",
          replicaSet: "replicaset",
          statefulSet: "statefulset",
          staticPod: "staticpod",
        },
        local workloadTypes = (
          if $._config.usePascalCaseForWorkloadTypeLabelValues then
            pascalCaseWorkloadTypes
          else
            downcaseWorkloadTypes
        ),
        local knownManagedPodOwnerMatchers = "%(daemonSet)s|%(deployment)s|%(job)s|%(replicaSet)s|%(statefulSet)s" % pascalCaseWorkloadTypes,
        local knownManagedJobOwnerMatchers = "%(pod)s" % pascalCaseWorkloadTypes,
        rules: [
          {
            // DaemonSet
            record: 'namespace_workload:kube_workload:relabel',
            expr: (
              |||
                (
                  max by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                    label_replace(label_replace(kube_daemonset_status_desired_number_scheduled{%(kubeStateMetricsSelector)s},
                      "workload", "$1", "daemonset", "(.+)"),
                    "workload_type", "%(daemonSet)s", "", "")
                  ) * 0
                ) + 1
              ||| % ($._config + workloadTypes)
            )
          },
          {
            // Deployment
            record: 'namespace_workload:kube_workload:relabel',
            expr: (
              |||
                (
                  max by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                    label_replace(label_replace(kube_deployment_spec_replicas{%(kubeStateMetricsSelector)s},
                      "workload", "$1", "deployment", "(.+)"),
                    "workload_type", "%(deployment)s", "", "")
                  ) * 0
                ) + 1
              ||| % ($._config + workloadTypes)
            )
          },
          {
            // Job (Bare/StandAlone)
            record: 'namespace_workload:kube_workload:relabel',
            expr: (
              |||
                (
                  max by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                    label_replace(label_replace(
                        (
                          kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind=""}
                          OR
                          (kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind!=""} unless on(%(clusterLabel)s, namespace, job_name) kube_job_owner{%(kubeStateMetricsSelector)s, owner_is_controller="true"})
                        ),
                        "workload", "$1", "job_name", "(.+)"),
                      "workload_type", "%(job)s", "", "")
                  ) * 0
                ) + 1
              ||| % ($._config + workloadTypes)
            )
          },
          {
            // Job (owned by Pod)
            record: 'namespace_workload:kube_workload:relabel',
            expr: (
              |||
                (
                  max by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                    label_replace(label_replace(kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind="Pod", owner_is_controller="true"},
                        "workload", "$1", "job_name", "(.+)"),
                      "workload_type", "%(job)s", "", "")
                  ) * 0
                ) + 1
              ||| % ($._config + workloadTypes)
            )
          },
          {
            // ReplicaSet (Bare/StandAlone)
            record: 'namespace_workload:kube_workload:relabel',
            expr: (
              |||
                (
                  max by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                    label_replace(label_replace(
                        max by(%(clusterLabel)s, %(namespaceLabel)s, replicaset) (kube_replicaset_spec_replicas{%(kubeStateMetricsSelector)s})
                          * on (%(clusterLabel)s, %(namespaceLabel)s, replicaset) group_left ()
                          max by(%(clusterLabel)s, %(namespaceLabel)s, replicaset) (kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind=""}),
                        "workload", "$1", "replicaset", "(.+)"),
                      "workload_type", "%(replicaSet)s", "", "")
                  ) * 0
                ) + 1
              ||| % ($._config + workloadTypes)
            )
          },
          {
            // StatefulSet
            record: 'namespace_workload:kube_workload:relabel',
            expr: (
              |||
                (
                  max by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                    label_replace(label_replace(kube_statefulset_replicas{%(kubeStateMetricsSelector)s},
                        "workload", "$1", "statefulset", "(.+)"),
                      "workload_type", "%(statefulSet)s", "", "")
                  ) * 0
                ) + 1
              ||| % ($._config + workloadTypes)
            )
          },
          {
            // workload aggregation for unknown pod owner types
            record: 'namespace_workload:kube_workload:relabel',
            expr: (
              |||
                (
                  (
                    max by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                      label_replace(
                        label_replace(
                          kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind!~"%(knownManagedPodOwnerMatchers)s", owner_kind!="", owner_is_controller="true"}
                          , "workload", "$1", "owner_name", "(.+)"
                        )
                      , "workload_type", "$1", "owner_kind", "(.+)")
                    )
                  ) * 0
                ) + 1
              ||| % ($._config + {knownManagedPodOwnerMatchers: knownManagedPodOwnerMatchers})
            )
          },
          {
            // workload aggregation for unknown job owner types (note: this includes cronjobs)
            record: 'namespace_workload:kube_workload:relabel',
            expr: (
              |||
                (
                  (
                    max by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                      label_replace(
                        label_replace(
                          kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind!~"%(knownManagedJobOwnerMatchers)s", owner_kind!="", owner_is_controller="true"}
                          , "workload", "$1", "owner_name", "(.+)"
                        )
                      , "workload_type", "$1", "owner_kind", "(.+)")
                    )
                  ) * 0
                ) + 1
              ||| % ($._config + {knownManagedJobOwnerMatchers: knownManagedJobOwnerMatchers})
            )
          },
          {
            record: 'namespace_workload:kube_pods_ready:sum',
            expr: (
              |||
                sum by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                  kube_pod_status_ready{%(kubeStateMetricsSelector)s, condition="true"}
                  * on (%(clusterLabel)s, %(namespaceLabel)s, pod) group_left (workload, workload_type)
                  namespace_workload_pod:kube_pod_owner:relabel
                )
              |||
            ) % $._config
          },
          {
            record: 'namespace_workload:kube_pods_phase:sum',
            expr: (
              |||
                sum by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type, phase) (
                  kube_pod_status_phase{%(kubeStateMetricsSelector)s}
                  * on (%(clusterLabel)s, %(namespaceLabel)s, pod) group_left (workload, workload_type)
                  namespace_workload_pod:kube_pod_owner:relabel
                )
              |||
            ) % $._config
          },
        ] + [
          {
            record: 'namespace_workload:kube_pods_desired:sum',
            expr: (
              |||
                sum by (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) (
                 label_replace(label_replace(%(workloadMetric)s{%(kubeStateMetricsSelector)s},
                     "workload", "$1", "%(workloadLabel)s", "(.+)"),
                   "workload_type", "%(workloadType)s", "", "")
                  * on (%(clusterLabel)s, %(namespaceLabel)s, workload, workload_type) group_left ()
                  namespace_workload:kube_workload:relabel
                )
              |||
            ) % ($._config + metricTuple),
            labels: {
              workload_type: metricTuple.workloadType
            },
          } for metricTuple in [
            {
              workloadMetric: "kube_daemonset_status_desired_number_scheduled",
              workloadLabel: "daemonset",
              workloadType: workloadTypes.daemonSet,
            },
            {
              workloadMetric: "kube_deployment_spec_replicas",
              workloadLabel: "deployment",
              workloadType: workloadTypes.deployment,
            },
            {
              workloadMetric: "kube_job_spec_completions",
              workloadLabel: "job_name",
              workloadType: workloadTypes.job,
            },
            {
              workloadMetric: "kube_replicaset_spec_replicas",
              workloadLabel: "replicaset",
              workloadType: workloadTypes.replicaSet,
            },
            {
              workloadMetric: "kube_statefulset_replicas",
              workloadLabel: "statefulset",
              workloadType: workloadTypes.statefulSet,
            },
          ]
        ]
      },
    ],
  },
}
