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
    notKubeDnsCoreDnsSelector: 'job!~"kube-dns|coredns"',
    kubeApiserverSelector: 'job="kube-apiserver"',
  },

  prometheusAlerts+:: {
    local additionalGrouping = utils.rejectGroupingLabels(
      $._config.additionalGrouping.alertingRules,
      ['__name__', 'alertname', 'code', 'git_version', 'severity'],
      'system alerting rules',
      'additionalGrouping.alertingRules'
    ),
    local groupingLabels(labels, excludedAdditionalLabels=[]) =
      utils.groupingLabels(labels, utils.withoutLabels(additionalGrouping, excludedAdditionalLabels)),
    local config = $._config {
      groupingVersion: groupingLabels(['git_version', $._config.clusterLabel]),
      groupingCluster: groupingLabels([$._config.clusterLabel], ['git_version']),
      groupingClient: groupingLabels([$._config.clusterLabel, 'instance', 'job', 'namespace'], ['code']),
    },

    groups+: [
      {
        name: 'kubernetes-system',
        rules: [
          {
            alert: 'KubeVersionMismatch',
            expr: |||
              count by (%(groupingCluster)s) (count by (%(groupingVersion)s) (label_replace(kubernetes_build_info{%(notKubeDnsCoreDnsSelector)s},"git_version","$1","git_version","(v[0-9]*.[0-9]*).*"))) > 1
            ||| % config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'There are {{ $value }} different semantic versions of Kubernetes components running%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Different semantic versions of Kubernetes components running.',
            },
          },
          {
            alert: 'KubeClientErrors',
            // Many clients use get requests to check the existence of objects,
            // this is normal and an expected error, therefore it should be
            // ignored in this alert.
            expr: |||
              (sum(rate(rest_client_requests_total{%(kubeApiserverSelector)s,code=~"5.."}[5m])) by (%(groupingClient)s)
                /
              sum(rate(rest_client_requests_total{%(kubeApiserverSelector)s}[5m])) by (%(groupingClient)s))
              > 0.01
            ||| % config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: "Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance }}' is experiencing {{ $value | humanizePercentage }} errors%s." % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubernetes API server client is experiencing errors.',
            },
          },
        ],
      },
    ],
  },
}
