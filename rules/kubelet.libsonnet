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
    kubeletSelector: 'job="kubelet"',
  },

  prometheusRules+:: {
    groups+: [
      {
        name: 'kubelet.rules',
        rules: [
          {
            record: 'node_quantile:kubelet_pleg_relist_duration_seconds:histogram_quantile',
            expr: (if $._config.nativeHistograms then |||
                     histogram_quantile(
                       %(quantile)s,
                       sum(rate(kubelet_pleg_relist_duration_seconds{%(kubeletSelector)s}[5m])) by (%(clusterLabel)s, instance)
                       * on(%(clusterLabel)s, instance) group_left (node)
                       max by (%(clusterLabel)s, instance, node) (kubelet_node_name{%(kubeletSelector)s})
                     )
                   ||| else |||
                     histogram_quantile(
                       %(quantile)s,
                       sum(rate(kubelet_pleg_relist_duration_seconds_bucket{%(kubeletSelector)s}[5m])) by (%(clusterLabel)s, instance, le)
                       * on(%(clusterLabel)s, instance) group_left (node)
                       max by (%(clusterLabel)s, instance, node) (kubelet_node_name{%(kubeletSelector)s})
                     )
                   |||) % ({ quantile: quantile } + $._config),
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
