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
    kubeletSelector: 'job="kubelet"',
  },

  prometheusRules+:: {
    local additionalGrouping = utils.withoutLabels($._config.additionalGrouping.recordingRules, ['quantile']),
    local groupingLabels(labels, excludedAdditionalLabels=[]) =
      utils.groupingLabels(labels, utils.withoutLabels(additionalGrouping, excludedAdditionalLabels)),
    local config = $._config {
      groupingClusterInstance: groupingLabels([$._config.clusterLabel, 'instance']),
      groupingClusterInstanceLe: groupingLabels([$._config.clusterLabel, 'instance', 'le']),
      groupingClusterInstanceNode: groupingLabels([$._config.clusterLabel, 'instance', 'node']),
      matchingClusterInstance: groupingLabels([$._config.clusterLabel, 'instance'], ['le', 'node', 'operation_type']),
    },

    groups+: [
      {
        name: 'kubelet.rules',
        rules: [
          {
            record: 'node_quantile:kubelet_pleg_relist_duration_seconds:histogram_quantile',
            expr: |||
              histogram_quantile(
                %(quantile)s,
                sum(rate(kubelet_pleg_relist_duration_seconds_bucket{%(kubeletSelector)s}[5m])) by (%(groupingClusterInstanceLe)s)
                * on(%(matchingClusterInstance)s) group_left (node)
                max by (%(groupingClusterInstanceNode)s) (kubelet_node_name{%(kubeletSelector)s})
              )
            ||| % ({ quantile: quantile } + config),
            labels: {
              quantile: quantile,
            },
          }
          for quantile in ['0.99', '0.9', '0.5']
        ],
      },
    ],
  },
}
