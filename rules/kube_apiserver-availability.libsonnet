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
    local additionalGrouping = utils.rejectGroupingLabels(
      $._config.additionalGrouping.recordingRules,
      ['__name__', 'code', 'le', 'resource', 'scope', 'verb'],
      'kube-apiserver availability recording rules',
      'additionalGrouping.recordingRules'
    ),
    local groupingLabels(labels) = utils.groupingLabels(labels, additionalGrouping),
    local config = $._config {
      groupingCluster: utils.groupingLabels(
        [$._config.clusterLabel],
        additionalGrouping
      ),
      groupingClusterVerbScope: groupingLabels([$._config.clusterLabel, 'verb', 'scope']),
      groupingClusterVerbScopeLe: groupingLabels([$._config.clusterLabel, 'verb', 'scope', 'le']),
    },
    local SLODays = $._config.SLOs.apiserver.days + 'd',
    local verbs = [
      { type: 'read', selector: $._config.kubeApiserverReadSelector },
      { type: 'write', selector: $._config.kubeApiserverWriteSelector },
    ],

    groups+: [
      {
        name: 'kube-apiserver-availability.rules',
        interval: '3m',
        rules: [
          {
            record: 'code_verb:apiserver_request_total:increase%s' % SLODays,
            expr: |||
              avg_over_time(code_verb:apiserver_request_total:increase1h[%s]) * 24 * %d
            ||| % [SLODays, $._config.SLOs.apiserver.days],
          },
        ] + [
          {
            record: 'code:apiserver_request_total:increase%s' % SLODays,
            expr: |||
              sum by (%s) (code_verb:apiserver_request_total:increase%s{%s})
            ||| % [groupingLabels([$._config.clusterLabel, 'code']), SLODays, verb.selector],
            labels: {
              verb: verb.type,
            },
          }
          for verb in verbs
        ] + [
          {
            record: 'cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase1h',
            expr: |||
              sum by (%(groupingClusterVerbScopeLe)s) (increase(apiserver_request_sli_duration_seconds_bucket[1h]))
            ||| % config,
          },
          {
            record: 'cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%s' % SLODays,
            expr: |||
              sum by (%s) (avg_over_time(cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase1h[%s]) * 24 * %s)
            ||| % [groupingLabels([$._config.clusterLabel, 'verb', 'scope', 'le']), SLODays, $._config.SLOs.apiserver.days],
          },
          {
            record: 'cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase1h',
            expr: |||
              sum by (%(groupingClusterVerbScope)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase1h{le="+Inf"})
            ||| % config,
          },
          {
            record: 'cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase%s' % SLODays,
            expr: |||
              sum by (%s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%s{le="+Inf"})
            ||| % [groupingLabels([$._config.clusterLabel, 'verb', 'scope']), SLODays],
          },
          {
            record: 'apiserver_request:availability%s' % SLODays,
            expr: |||
              1 - (
                (
                  # write too slow
                  sum by (%(groupingCluster)s) (cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase%(SLODays)s{%(kubeApiserverWriteSelector)s})
                  -
                  sum by (%(groupingCluster)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverWriteSelector)s,le=~"%(kubeApiserverWriteLatency)s"} or vector(0))
                ) +
                (
                  # read too slow
                  sum by (%(groupingCluster)s) (cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase%(SLODays)s{%(kubeApiserverReadSelector)s})
                  -
                  (
                    sum by (%(groupingCluster)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope=~"resource|",le=~"%(kubeApiserverReadResourceLatency)s"} or vector(0))
                    +
                    sum by (%(groupingCluster)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope="namespace",le=~"%(kubeApiserverReadNamespaceLatency)s"} or vector(0))
                    +
                    sum by (%(groupingCluster)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope="cluster",le=~"%(kubeApiserverReadClusterLatency)s"} or vector(0))
                  )
                ) +
                # errors
                sum by (%(groupingCluster)s) (code:apiserver_request_total:increase%(SLODays)s{code=~"5.."} or vector(0))
              )
              /
              sum by (%(groupingCluster)s) (code:apiserver_request_total:increase%(SLODays)s)
            ||| % (config { SLODays: SLODays }),
            labels: {
              verb: 'all',
            },
          },
          {
            record: 'apiserver_request:availability%s' % SLODays,
            expr: |||
              1 - (
                sum by (%(groupingCluster)s) (cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase%(SLODays)s{%(kubeApiserverReadSelector)s})
                -
                (
                  # too slow
                  sum by (%(groupingCluster)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope=~"resource|",le=~"%(kubeApiserverReadResourceLatency)s"} or vector(0))
                  +
                  sum by (%(groupingCluster)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope="namespace",le=~"%(kubeApiserverReadNamespaceLatency)s"} or vector(0))
                  +
                  sum by (%(groupingCluster)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope="cluster",le=~"%(kubeApiserverReadClusterLatency)s"} or vector(0))
                )
                +
                # errors
                sum by (%(groupingCluster)s) (code:apiserver_request_total:increase%(SLODays)s{verb="read",code=~"5.."} or vector(0))
              )
              /
              sum by (%(groupingCluster)s) (code:apiserver_request_total:increase%(SLODays)s{verb="read"})
            ||| % (config { SLODays: SLODays, days: $._config.SLOs.apiserver.days }),
            labels: {
              verb: 'read',
            },
          },
          {
            record: 'apiserver_request:availability%s' % SLODays,
            expr: |||
              1 - (
                (
                  # too slow
                  sum by (%(groupingCluster)s) (cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase%(SLODays)s{%(kubeApiserverWriteSelector)s})
                  -
                  sum by (%(groupingCluster)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverWriteSelector)s,le=~"%(kubeApiserverWriteLatency)s"} or vector(0))
                )
                +
                # errors
                sum by (%(groupingCluster)s) (code:apiserver_request_total:increase%(SLODays)s{verb="write",code=~"5.."} or vector(0))
              )
              /
              sum by (%(groupingCluster)s) (code:apiserver_request_total:increase%(SLODays)s{verb="write"})
            ||| % (config { SLODays: SLODays, days: $._config.SLOs.apiserver.days }),
            labels: {
              verb: 'write',
            },
          },
        ] + [
          {
            record: 'code_resource:apiserver_request_total:rate5m',
            expr: |||
              sum by (%s) (rate(apiserver_request_total{%s}[5m]))
            ||| % [groupingLabels([$._config.clusterLabel, 'code', 'resource']), std.join(',', [$._config.kubeApiserverSelector, verb.selector])],
            labels: {
              verb: verb.type,
            },
          }
          for verb in verbs
        ] + [
          {
            record: 'code_verb:apiserver_request_total:increase1h',
            expr: |||
              sum by (%s) (increase(apiserver_request_total{%s,verb=~"LIST|GET|POST|PUT|PATCH|DELETE",code=~"%s"}[1h]))
            ||| % [groupingLabels([$._config.clusterLabel, 'code', 'verb']), $._config.kubeApiserverSelector, code],
          }
          for code in ['2..', '3..', '4..', '5..']
        ],
      },
    ],
  },
}
