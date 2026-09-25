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

local defaultQueries = import './queries/namespace-by-workload.libsonnet';
local defaultVariables = import './variables/namespace-by-workload.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local annotations = import '../../lib/annotations.libsonnet';
local barGauge = g.panel.barGauge;
local prometheus = g.query.prometheus;
local table = g.panel.table;
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
    'namespace-by-workload.json':
      // Allow overriding queries via $._queries.namespaceByWorkload, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'namespaceByWorkload')
      then $._queries.namespaceByWorkload
      else defaultQueries;

      // Allow overriding variables via $._variables.namespaceByWorkload, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'namespaceByWorkload')
      then $._variables.namespaceByWorkload($._config)
      else defaultVariables.namespaceByWorkload($._config);

      local links = {
        workload: {
          title: 'Drill down',
          url: '%(prefix)s/d/%(uid)s?${datasource:queryparam}&var-cluster=${cluster}&var-namespace=${namespace}&var-type=${__data.fields.Type}&var-workload=${__data.fields.Workload}' % {
            uid: $._config.grafanaDashboardIDs['workload-total.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local colQueries = queries.currentStatusColumns($._config);

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

        table.new('Current Status')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', colQueries[0])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[1])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[2])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[3])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[4])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[5])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[6])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[7])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])
        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'workload',
            mode: 'outer',
          }),

          g.panel.table.queryOptions.transformation.withId('organize')
          + g.panel.table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
              'Time 6': true,
              'Time 7': true,
              'Time 8': true,
              'workload_type 2': true,
              'workload_type 3': true,
              'workload_type 4': true,
              'workload_type 5': true,
              'workload_type 6': true,
              'workload_type 7': true,
              'workload_type 8': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              'Time 7': 6,
              'Time 8': 7,
              workload: 8,
              'workload_type 1': 9,
              'Value #A': 10,
              'Value #B': 11,
              'Value #C': 12,
              'Value #D': 13,
              'Value #E': 14,
              'Value #F': 15,
              'Value #G': 16,
              'Value #H': 17,
              'workload_type 2': 18,
              'workload_type 3': 19,
              'workload_type 4': 20,
              'workload_type 5': 21,
              'workload_type 6': 22,
              'workload_type 7': 23,
              'workload_type 8': 24,
            },
            renameByName: {
              workload: 'Workload',
              'workload_type 1': 'Type',
              'Value #A': 'Rx %(unit)s' % { unit: $._config.units.networkUnitLabel },
              'Value #B': 'Tx %(unit)s' % { unit: $._config.units.networkUnitLabel },
              'Value #C': 'Rx %(unit)s (Avg)' % { unit: $._config.units.networkUnitLabel },
              'Value #D': 'Tx %(unit)s (Avg)' % { unit: $._config.units.networkUnitLabel },
              'Value #E': 'Rx Packets',
              'Value #F': 'Tx Packets',
              'Value #G': 'Rx Packets Dropped',
              'Value #H': 'Tx Packets Dropped',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%(unit)s/' % { unit: $._config.units.networkUnitLabel },
            },
            properties: [
              {
                id: 'unit',
                value: $._config.units.network,
              },
            ],
          },
          {
            matcher: {
              id: 'byRegexp',
              options: '/Packets/',
            },
            properties: [
              {
                id: 'unit',
                value: 'pps',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Workload',
            },
            properties: [
              {
                id: 'links',
                value: [links.workload],
              },
            ],
          },
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

        tsPanel.new('Average Container Bandwidth by Workload: Received')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.avgContainerReceiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Container Bandwidth by Workload: Transmitted')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.avgContainerTransmitBandwidth($._config)
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

      g.dashboard.new('%(dashboardNamePrefix)sNetworking / Namespace (Workload)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['namespace-by-workload.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.workload_type])
      + annotations.withContainerRestarts($._config.grafanaK8s.containerRestartAnnotation, $._config.grafanaK8s.containerRestartAnnotationEnable)
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=9)),
  },
}
