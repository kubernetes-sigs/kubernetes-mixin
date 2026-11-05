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
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    podLabel: 'pod',
  },

  prometheusRules+:: {
    groups+: [
      {
        name: 'node.rules',
        rules: [
          {
            // This rule results in the tuples (node, namespace, instance) => 1.
            // It is used to calculate per-node metrics, given namespace & instance.
            // We use the topk() aggregator to ensure that each (namespace,
            // instance) tuple is only associated to one node and thus avoid
            // "many-to-many matching not allowed" errors when joining with
            // other timeseries on (namespace, instance). See node:node_num_cpu:sum
            // below for instance.
            record: 'node_namespace_pod:kube_pod_info:',
            expr: |||
              topk by(%(clusterLabel)s, namespace, %(podLabel)s) (1,
                max by (%(clusterLabel)s, node, namespace, %(podLabel)s) (
                  label_replace(kube_pod_info{%(kubeStateMetricsSelector)s,node!=""}, "%(podLabel)s", "$1", "pod", "(.*)")
              ))
            ||| % $._config,
          },
          {
            // This rule gives the number of CPUs per node.
            record: 'node:node_num_cpu:sum',
            expr: |||
              count by (%(clusterLabel)s, node) (
                node_cpu_seconds_total{mode="idle",%(nodeExporterSelector)s}
                * on (%(clusterLabel)s, namespace, %(podLabel)s) group_left(node)
                topk by(%(clusterLabel)s, namespace, %(podLabel)s) (1, node_namespace_pod:kube_pod_info:)
              )
            ||| % $._config,
          },
          // Add separate rules for Available memory, so we can aggregate across clusters in dashboards.
          {
            record: ':node_memory_MemAvailable_bytes:sum',
            expr: |||
              sum(
                node_memory_MemAvailable_bytes{%(nodeExporterSelector)s} or
                (
                  node_memory_Buffers_bytes{%(nodeExporterSelector)s} +
                  node_memory_Cached_bytes{%(nodeExporterSelector)s} +
                  node_memory_MemFree_bytes{%(nodeExporterSelector)s} +
                  node_memory_Slab_bytes{%(nodeExporterSelector)s}
                )
              ) by (%(clusterLabel)s)
            ||| % $._config,
          },
          {
            // This rule gives cpu utilization per node.
            record: 'node:node_cpu_utilization:ratio_rate5m',
            expr: |||
              avg by (%(clusterLabel)s, node) (
                sum without (mode) (
                  rate(node_cpu_seconds_total{mode!="idle",mode!="iowait",mode!="steal",%(nodeExporterSelector)s}[5m])
                )
                * on (%(clusterLabel)s, namespace, %(podLabel)s) group_left(node)
                topk by(%(clusterLabel)s, namespace, %(podLabel)s) (1, node_namespace_pod:kube_pod_info:)
              )
            ||| % $._config,
          },
          {
            // This rule gives cpu utilization per cluster, weighted by the
            // number of CPUs of each node.
            record: 'cluster:node_cpu:ratio_rate5m',
            expr: |||
              sum by (%(clusterLabel)s) (
                node:node_cpu_utilization:ratio_rate5m
                * on (%(clusterLabel)s, node)
                node:node_num_cpu:sum
              )
              /
              sum by (%(clusterLabel)s) (
                node:node_num_cpu:sum
              )
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
