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

local defaultQueries = import './queries/pod-total.libsonnet';
local defaultVariables = import './variables/pod-total.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local annotations = import '../../lib/annotations.libsonnet';
local gauge = g.panel.gauge;
local prometheus = g.query.prometheus;
local timeSeries = g.panel.timeSeries;

{
  local tsPanel =
    timeSeries {
      new(title):
        timeSeries.new(title)
        + timeSeries.options.legend.withShowLegend()
        + timeSeries.options.legend.withAsTable()
        + timeSeries.options.legend.withDisplayMode('table')
        + timeSeries.options.legend.withPlacement('right')
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  grafanaDashboards+:: {
    'pod-total.json':
      // Allow overriding queries via $._queries.podTotal, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'podTotal')
      then $._queries.podTotal
      else defaultQueries;

      // Allow overriding variables via $._variables.podTotal, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'podTotal')
      then $._variables.podTotal($._config)
      else defaultVariables.podTotal($._config);

      local panels = [
        gauge.new('Current Rate of %(unit)s Received' % { unit: $._config.units.networkUnitLabel })
        + gauge.standardOptions.withDisplayName('$pod')
        + gauge.standardOptions.withUnit($._config.units.network)
        + gauge.standardOptions.withMin(0)
        + gauge.standardOptions.withMax(10000000000)  // 10Gbps
        + gauge.standardOptions.thresholds.withSteps([
          {
            color: 'dark-green',
            index: 0,
            value: null,  // 0Gbps
          },
          {
            color: 'dark-yellow',
            index: 1,
            value: 5000000000,  // 5Gbps
          },
          {
            color: 'dark-red',
            index: 2,
            value: 7000000000,  // 7Gbps
          },
        ])
        + gauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + gauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.gaugeReceiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        gauge.new('Current Rate of %(unit)s Transmitted' % { unit: $._config.units.networkUnitLabel })
        + gauge.standardOptions.withDisplayName('$pod')
        + gauge.standardOptions.withUnit($._config.units.network)
        + gauge.standardOptions.withMin(0)
        + gauge.standardOptions.withMax(10000000000)  // 10Gbps
        + gauge.standardOptions.thresholds.withSteps([
          {
            color: 'dark-green',
            index: 0,
            value: null,  // 0Gbps
          },
          {
            color: 'dark-yellow',
            index: 1,
            value: 5000000000,  // 5Gbps
          },
          {
            color: 'dark-red',
            index: 2,
            value: 7000000000,  // 7Gbps
          },
        ])
        + gauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + gauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.gaugeTransmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.receiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.transmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.receivePackets($._config))
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.transmitPackets($._config))
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.receivePacketsDropped($._config))
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.transmitPacketsDropped($._config))
          + prometheus.withLegendFormat('__auto'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sNetworking / Pod' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['pod-total.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.pod])
      + annotations.withContainerRestarts($._config.grafanaK8s.containerRestartAnnotation, $._config.grafanaK8s.containerRestartAnnotationEnable)
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=9)),
  },
}
