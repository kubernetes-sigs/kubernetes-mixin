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
      ['__name__', 'le', 'quantile', 'verb'],
      'kube-apiserver histogram recording rules',
      'additionalGrouping.recordingRules'
    ),
    local groupingLabels(labels) = utils.groupingLabels(labels, additionalGrouping),
    local verbs = [
      { type: 'read', selector: $._config.kubeApiserverReadSelector },
      { type: 'write', selector: $._config.kubeApiserverWriteSelector },
    ],

    groups+: [
      {
        name: 'kube-apiserver-histogram.rules',
        rules:
          [
            {
              record: 'cluster_quantile:apiserver_request_sli_duration_seconds:histogram_quantile',
              expr: |||
                histogram_quantile(0.99, sum by (%s) (rate(apiserver_request_sli_duration_seconds_bucket{%s}[5m]))) > 0
              ||| % [groupingLabels([$._config.clusterLabel, 'le', 'resource']), std.join(',', [$._config.kubeApiserverSelector, verb.selector, $._config.kubeApiserverNonStreamingSelector])],
              labels: {
                verb: verb.type,
                quantile: '0.99',
              },
            }
            for verb in verbs
          ],
      },
    ],
  },
}
