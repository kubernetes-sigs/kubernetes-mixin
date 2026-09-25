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

local defaultQueries = import './queries/workload-total.libsonnet';
local defaultVariables = import './variables/workload-total.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local annotations = import '../../lib/annotations.libsonnet';
local barGauge = g.panel.barGauge;
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
        + timeSeries.options.legend.withCalcs(['lastNotNull'])
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withSpanNulls(true)
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  grafanaDashboards+:: {
    'workload-total.json':
      // Allow overriding queries via $._queries.workloadTotal, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'workloadTotal')
      then $._queries.workloadTotal
      else defaultQueries;

      // Allow overriding variables via $._variables.workloadTotal, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'workloadTotal')
      then $._variables.workloadTotal($._config)
      else defaultVariables.workloadTotal($._config);

      local panels = [
        barGauge.new('Current Rate of %(unit)s Received' % { unit: $._config.units.networkUnitLabel })
        + barGauge.options.withDisplayMode('basic')
        + barGauge.options.withShowUnfilled(false)
        + barGauge.standardOptions.withUnit($._config.units.network)
        + barGauge.standardOptions.color.withMode('fixed')
        + barGauge.standardOptions.color.withFixedColor('green')
        + barGauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + barGauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.receiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        barGauge.new('Current Rate of %(unit)s Transmitted' % { unit: $._config.units.networkUnitLabel })
        + barGauge.options.withDisplayMode('basic')
        + barGauge.options.withShowUnfilled(false)
        + barGauge.standardOptions.withUnit($._config.units.network)
        + barGauge.standardOptions.color.withMode('fixed')
        + barGauge.standardOptions.color.withFixedColor('green')
        + barGauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + barGauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.transmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        barGauge.new('Average Rate of %(unit)s Received' % { unit: $._config.units.networkUnitLabel })
        + barGauge.options.withDisplayMode('basic')
        + barGauge.options.withShowUnfilled(false)
        + barGauge.standardOptions.withUnit($._config.units.network)
        + barGauge.standardOptions.color.withMode('fixed')
        + barGauge.standardOptions.color.withFixedColor('green')
        + barGauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + barGauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.avgReceiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        barGauge.new('Average Rate of %(unit)s Transmitted' % { unit: $._config.units.networkUnitLabel })
        + barGauge.options.withDisplayMode('basic')
        + barGauge.options.withShowUnfilled(false)
        + barGauge.standardOptions.withUnit($._config.units.network)
        + barGauge.standardOptions.color.withMode('fixed')
        + barGauge.standardOptions.color.withFixedColor('green')
        + barGauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + barGauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.avgTransmitBandwidth($._config)
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
          prometheus.new(
            '${datasource}',
            queries.rateReceivedPackets($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.rateTransmittedPackets($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.rateReceivedPacketsDropped($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.rateTransmittedPacketsDropped($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sNetworking / Workload' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['workload-total.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.workload, variables.workload_type])
      + annotations.withContainerRestarts($._config.grafanaK8s.containerRestartAnnotation, $._config.grafanaK8s.containerRestartAnnotationEnable, annotations.containerRestartsByWorkloadExpr)
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=9)),
  },
}
