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

local defaultQueries = import './queries/namespace-by-pod.libsonnet';
local defaultVariables = import './variables/namespace-by-pod.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local annotations = import '../../lib/annotations.libsonnet';
local gauge = g.panel.gauge;
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
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  grafanaDashboards+:: {
    'namespace-by-pod.json':
      // Allow overriding queries via $._queries.namespaceByPod, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'namespaceByPod')
      then $._queries.namespaceByPod
      else defaultQueries;

      // Allow overriding variables via $._variables.namespaceByPod, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'namespaceByPod')
      then $._variables.namespaceByPod($._config)
      else defaultVariables.namespaceByPod($._config);

      local links = {
        pod: {
          title: 'Drill down',
          url: '%(prefix)s/d/%(uid)s?${datasource:queryparam}&var-cluster=${cluster}&var-namespace=${namespace}&var-pod=${__data.fields.Pod}' % {
            uid: $._config.grafanaDashboardIDs['pod-total.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local panels = [
        gauge.new('Current Rate of %(unit)s Received' % { unit: $._config.units.networkUnitLabel })
        + gauge.standardOptions.withDisplayName('$namespace')
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
            '${datasource}', queries.gaugeReceiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        gauge.new('Current Rate of %(unit)s Transmitted' % { unit: $._config.units.networkUnitLabel })
        + gauge.standardOptions.withDisplayName('$namespace')
        + gauge.standardOptions.withUnit($._config.units.network)
        + gauge.standardOptions.withMin(0)
        + gauge.standardOptions.withMax(10000000000)  // 10Gbps
        + gauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
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
        + gauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.gaugeTransmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Current Network Usage')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.receiveBandwidth($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.transmitBandwidth($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.receivePackets($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.transmitPackets($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.receivePacketsDropped($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.transmitPacketsDropped($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'pod',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
              'Time 6': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              pod: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              pod: 'Pod',
              'Value #A': 'Current Receive Bandwidth',
              'Value #B': 'Current Transmit Bandwidth',
              'Value #C': 'Rate of Received Packets',
              'Value #D': 'Rate of Transmitted Packets',
              'Value #E': 'Rate of Received Packets Dropped',
              'Value #F': 'Rate of Transmitted Packets Dropped',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/Bandwidth/',
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
              options: 'Pod',
            },
            properties: [
              {
                id: 'links',
                value: [links.pod],
              },
            ],
          },
        ]),

        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.receiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.transmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.receivePackets($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.transmitPackets($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.receivePacketsDroppedTimeSeries($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.transmitPacketsDropped($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sNetworking / Namespace (Pods)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['namespace-by-pod.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace])
      + annotations.withContainerRestarts($._config.grafanaK8s.containerRestartAnnotation, $._config.grafanaK8s.containerRestartAnnotationEnable)
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=9)),
  },
}
