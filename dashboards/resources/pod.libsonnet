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

local defaultQueries = import './queries/pod.libsonnet';
local defaultVariables = import './variables/pod.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

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
    'k8s-resources-pod.json':
      // Allow overriding queries via $._queries.pod, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'pod')
      then $._queries.pod
      else defaultQueries;

      // Allow overriding variables via $._variables.pod, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'pod')
      then $._variables.pod($._config)
      else defaultVariables.pod($._config);

      local panels = [
        tsPanel.new('CPU Usage')
        + tsPanel.gridPos.withW(24)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.cpuUsageByContainer($._config)
          )
          + prometheus.withLegendFormat('__auto'),

          prometheus.new('${datasource}', queries.cpuRequests($._config))
          + prometheus.withLegendFormat('requests'),

          prometheus.new('${datasource}', queries.cpuLimits($._config))
          + prometheus.withLegendFormat('limits'),
        ])
        + tsPanel.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byFrameRefID',
              options: 'B',
            },
            properties: [
              {
                id: 'custom.lineStyle',
                value: {
                  fill: 'dash',
                },
              },
              {
                id: 'custom.lineWidth',
                value: 2,
              },
              {
                id: 'color',
                value: {
                  mode: 'fixed',
                  fixedColor: 'red',
                },
              },
            ],
          },
          {
            matcher: {
              id: 'byFrameRefID',
              options: 'C',
            },
            properties: [
              {
                id: 'custom.lineStyle',
                value: {
                  fill: 'dash',
                },
              },
              {
                id: 'custom.lineWidth',
                value: 2,
              },
              {
                id: 'color',
                value: {
                  mode: 'fixed',
                  fixedColor: 'orange',
                },
              },
            ],
          },
        ]),

        tsPanel.new('CPU Throttling')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.cpuThrottling($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ])
        + tsPanel.fieldConfig.defaults.custom.withAxisSoftMin(0)
        + tsPanel.fieldConfig.defaults.custom.withAxisSoftMax(1)
        + tsPanel.fieldConfig.defaults.custom.thresholdsStyle.withMode('dashed+area')
        + tsPanel.fieldConfig.defaults.custom.withAxisColorMode('thresholds')
        + tsPanel.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byFrameRefID',
              options: 'A',
            },
            properties: [
              {
                id: 'thresholds',
                value: {
                  mode: 'absolute',
                  steps: [
                    {
                      color: 'green',
                      value: null,
                    },
                    {
                      color: 'red',
                      value: $._config.cpuThrottlingPercent / 100,
                    },
                  ],
                },
              },
              {
                id: 'color',
                value: {
                  mode: 'thresholds',
                  seriesBy: 'lastNotNull',
                },
              },
            ],
          },
        ]),

        table.new('CPU Quota')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.cpuUsageByContainer($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.cpuRequestsByContainer($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.cpuUsageVsRequests($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.cpuLimitsByContainer($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.cpuUsageVsLimits($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.cpuThrottling($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.cpuThrottledSeconds($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])
        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'container',
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
              'Time 7': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              'Time 7': 6,
              container: 7,
              'Value #A': 8,
              'Value #B': 9,
              'Value #C': 10,
              'Value #D': 11,
              'Value #E': 12,
              'Value #F': 13,
              'Value #G': 14,
            },
            renameByName: {
              container: 'Container',
              'Value #A': 'CPU Usage',
              'Value #B': 'CPU Requests',
              'Value #C': 'CPU Requests %',
              'Value #D': 'CPU Limits',
              'Value #E': 'CPU Limits %',
              'Value #F': 'CPU Throttling %',
              'Value #G': 'CPU Throttled Seconds',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'CPU Throttled Seconds',
            },
            properties: [
              {
                id: 'unit',
                value: 's',
              },
            ],
          },
        ]),

        tsPanel.new('Memory Usage (WSS)')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.memoryUsageWSS($._config)
          )
          + prometheus.withLegendFormat('__auto'),

          prometheus.new('${datasource}', queries.memoryRequests($._config))
          + prometheus.withLegendFormat('requests'),

          prometheus.new('${datasource}', queries.memoryLimits($._config))
          + prometheus.withLegendFormat('limits'),
        ])
        + tsPanel.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byFrameRefID',
              options: 'B',
            },
            properties: [
              {
                id: 'custom.lineStyle',
                value: {
                  fill: 'dash',
                },
              },
              {
                id: 'custom.lineWidth',
                value: 2,
              },
              {
                id: 'color',
                value: {
                  mode: 'fixed',
                  fixedColor: 'red',
                },
              },
            ],
          },
          {
            matcher: {
              id: 'byFrameRefID',
              options: 'C',
            },
            properties: [
              {
                id: 'custom.lineStyle',
                value: {
                  fill: 'dash',
                },
              },
              {
                id: 'custom.lineWidth',
                value: 2,
              },
              {
                id: 'color',
                value: {
                  mode: 'fixed',
                  fixedColor: 'orange',
                },
              },
            ],
          },
        ]),

        table.new('Memory Quota')
        + table.gridPos.withW(24)
        + table.standardOptions.withUnit('bytes')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.memoryUsageWSS($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryRequestsByContainer($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryUsageVsRequests($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryLimitsByContainer($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryUsageVsLimits($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryUsageRSS($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryUsageCache($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryUsageSwap($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])
        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'container',
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
              'Time 7': true,
              'Time 8': true,
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
              container: 8,
              'Value #A': 9,
              'Value #B': 10,
              'Value #C': 11,
              'Value #D': 12,
              'Value #E': 13,
              'Value #F': 14,
              'Value #G': 15,
              'Value #H': 16,
            },
            renameByName: {
              container: 'Container',
              'Value #A': 'Memory Usage',
              'Value #B': 'Memory Requests',
              'Value #C': 'Memory Requests %',
              'Value #D': 'Memory Limits',
              'Value #E': 'Memory Limits %',
              'Value #F': 'Memory Usage (RSS)',
              'Value #G': 'Memory Usage (Cache)',
              'Value #H': 'Memory Usage (Swap)',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
              },
            ],
          },
        ]),


        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.networkReceiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.networkTransmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.networkReceivePackets($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.networkTransmitPackets($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.networkReceivePacketsDropped($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.networkTransmitPacketsDropped($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('IOPS (Pod)')
        + tsPanel.standardOptions.withUnit('iops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.iopsPodReads($._config)
          )
          + prometheus.withLegendFormat('Reads'),
          prometheus.new(
            '${datasource}',
            queries.iopsPodWrites($._config)
          )
          + prometheus.withLegendFormat('Writes'),
        ]),

        tsPanel.new('ThroughPut (Pod)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.throughputPodRead($._config)
          )
          + prometheus.withLegendFormat('Reads'),
          prometheus.new(
            '${datasource}',
            queries.throughputPodWrite($._config)
          )
          + prometheus.withLegendFormat('Writes'),
        ]),

        tsPanel.new('IOPS (Containers)')
        + tsPanel.standardOptions.withUnit('iops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.iopsContainersCombined($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('ThroughPut (Containers)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.throughputContainersCombined($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Current Storage IO')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.storageReads($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.storageWrites($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.storageReadsPlusWrites($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.storageReadBytes($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.storageWriteBytes($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.storageReadPlusWriteBytes($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'container',
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
              container: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              container: 'Container',
              'Value #A': 'IOPS(Reads)',
              'Value #B': 'IOPS(Writes)',
              'Value #C': 'IOPS(Reads + Writes)',
              'Value #D': 'Throughput(Read)',
              'Value #E': 'Throughput(Write)',
              'Value #F': 'Throughput(Read + Write)',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/IOPS/',
            },
            properties: [
              {
                id: 'unit',
                value: 'iops',
              },
            ],
          },
          {
            matcher: {
              id: 'byRegexp',
              options: '/Throughput/',
            },
            properties: [
              {
                id: 'unit',
                value: 'Bps',
              },
            ],
          },
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Pod' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-pod.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.pod])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=7)),
  },
}
