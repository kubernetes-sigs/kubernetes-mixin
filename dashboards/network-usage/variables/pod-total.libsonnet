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

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local var = g.dashboard.variable;

{
  podTotal(config):: {
    datasource:
      var.datasource.new('datasource', 'prometheus')
      + var.datasource.withRegex(config.datasourceFilterRegex)
      + var.datasource.generalOptions.showOnDashboard.withLabelAndValue()
      + var.datasource.generalOptions.withLabel('Data source')
      + {
        current: {
          selected: true,
          text: config.datasourceName,
          value: config.datasourceName,
        },
      },

    cluster:
      var.query.new('cluster')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        config.clusterLabel,
        'up{%(cadvisorSelector)s}' % config,
      )
      + var.query.generalOptions.withLabel('cluster')
      + var.query.refresh.onTime()
      + (
        if config.showMultiCluster
        then var.query.generalOptions.showOnDashboard.withLabelAndValue()
        else var.query.generalOptions.showOnDashboard.withNothing()
      )
      + var.query.withSort(type='alphabetical'),

    namespace:
      var.query.new('namespace')
      + var.query.selectionOptions.withIncludeAll(true, '.+')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'namespace',
        'container_network_receive_packets_total{%(clusterLabel)s="$cluster"}' % config,
      )
      + var.query.generalOptions.withCurrent('kube-system')
      + var.query.generalOptions.withLabel('namespace')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue()
      + var.query.withSort(type='alphabetical'),

    pod:
      var.query.new('pod')
      + var.query.withDatasourceFromVariable(self.datasource)
      // Keep historical pods only when they have samples in the selected range.
      + var.query.queryTypes.withQueryResult(
        'count by (pod) (count_over_time(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[${__range_s}s]))' % config,
      )
      + var.query.withRegex('/pod="([^"]+)"/')
      + var.query.generalOptions.withCurrent('kube-system')
      + var.query.generalOptions.withLabel('pod')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue()
      + var.query.withSort(type='alphabetical'),
  },
}
