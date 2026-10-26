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
    kubeSchedulerSelector: 'job="kube-scheduler"',
    podLabel: 'pod',
  },

  prometheusRules+:: {
    local configuredAdditionalGrouping = utils.rejectLabelsExcludedByWithout(
      $._config.additionalGrouping.recordingRules,
      ['instance', $._config.podLabel],
      'kube-scheduler rules',
      'additionalGrouping.recordingRules'
    ),
    assert utils.rejectGroupingLabels(
      configuredAdditionalGrouping,
      ['__name__', 'le', 'quantile'],
      'kube-scheduler recording rules',
      'additionalGrouping.recordingRules'
    ) == configuredAdditionalGrouping,

    groups+: [
      {
        name: 'kube-scheduler.rules',
        rules: [
          {
            record: 'cluster_quantile:%s:histogram_quantile' % metric,
            expr: |||
              histogram_quantile(%(quantile)s, sum(rate(%(metric)s_bucket{%(kubeSchedulerSelector)s}[5m])) without(instance, %(podLabel)s))
            ||| % ({ quantile: quantile, metric: metric } + $._config),
            labels: {
              quantile: quantile,
            },
          }
          for quantile in ['0.99', '0.9', '0.5']
          for metric in [
            'scheduler_scheduling_attempt_duration_seconds',
            'scheduler_scheduling_algorithm_duration_seconds',
            'scheduler_pod_scheduling_sli_duration_seconds',
          ]
        ],
      },
    ],
  },
}
