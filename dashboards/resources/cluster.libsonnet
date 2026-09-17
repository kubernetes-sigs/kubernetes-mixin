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

local defaultQueries = import './queries/cluster.libsonnet';
local defaultVariables = import './variables/cluster.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local table = g.panel.table;
local timeSeries = g.panel.timeSeries;

{
  local statPanel(title, unit, query) =
    stat.new(title)
    + stat.options.withColorMode('none')
    + stat.standardOptions.withUnit(unit)
    + stat.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
    + stat.queryOptions.withTargets([
      prometheus.new('${datasource}', query)
      + prometheus.withInstant(true),
    ]),

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
    'k8s-resources-cluster.json':
      // Allow overriding queries via $._queries.cluster, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'cluster')
      then $._queries.cluster
      else defaultQueries;

      // Allow overriding variables via $._variables.cluster, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'cluster')
      then $._variables.cluster($._config)
      else defaultVariables.cluster($._config);

      local links = {
        namespace: {
          title: 'Drill down to pods',
          url: '%(prefix)s/d/%(uid)s?${datasource:queryparam}&var-cluster=$cluster&var-namespace=${__data.fields.Namespace}' % {
            uid: $._config.grafanaDashboardIDs['k8s-resources-namespace.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local panels = [
        statPanel(
          'CPU Utilisation',
          'percentunit',
          queries.cpuUtilisation($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'CPU Requests Commitment',
          'percentunit',
          queries.cpuRequestsCommitment($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'CPU Limits Commitment',
          'percentunit',
          queries.cpuLimitsCommitment($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Utilisation',
          'percentunit',
          queries.memoryUtilisation($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Requests Commitment',
          'percentunit',
          queries.memoryRequestsCommitment($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Limits Commitment',
          'percentunit',
          queries.memoryLimitsCommitment($._config)
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        tsPanel.new('CPU Usage')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.cpuUsageByNamespace($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('CPU Throttling')
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
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.podsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.workloadsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.cpuUsageByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.cpuRequestsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.cpuUsageVsRequests($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.cpuLimitsByNamespace($._config))
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
            byField: 'namespace',
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
              'Time 9': true,
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
              'Time 9': 8,
              namespace: 9,
              'Value #A': 10,
              'Value #B': 11,
              'Value #C': 12,
              'Value #D': 13,
              'Value #E': 14,
              'Value #F': 15,
              'Value #G': 16,
              'Value #H': 17,
              'Value #I': 18,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'Pods',
              'Value #B': 'Workloads',
              'Value #C': 'CPU Usage',
              'Value #D': 'CPU Requests',
              'Value #E': 'CPU Requests %',
              'Value #F': 'CPU Limits',
              'Value #G': 'CPU Limits %',
              'Value #H': 'CPU Throttling %',
              'Value #I': 'CPU Throttled Seconds',
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
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),

        tsPanel.new('Memory')
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.memoryUsageByNamespace($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Memory Requests by Namespace')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.podsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.workloadsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.memoryUsageByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.memoryRequestsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.memoryUsageVsRequests($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.memoryLimitsByNamespace($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.memoryUsageVsLimits($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
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
              namespace: 7,
              'Value #A': 8,
              'Value #B': 9,
              'Value #C': 10,
              'Value #D': 11,
              'Value #E': 12,
              'Value #F': 13,
              'Value #G': 14,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'Pods',
              'Value #B': 'Workloads',
              'Value #C': 'Memory Usage',
              'Value #D': 'Memory Requests',
              'Value #E': 'Memory Requests %',
              'Value #F': 'Memory Limits',
              'Value #G': 'Memory Limits %',
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
              options: 'Memory Usage',
            },
            properties: [
              {
                id: 'unit',
                value: 'bytes',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Memory Requests',
            },
            properties: [
              {
                id: 'unit',
                value: 'bytes',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Memory Limits',
            },
            properties: [
              {
                id: 'unit',
                value: 'bytes',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),

        table.new('Current Network Usage')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.networkReceiveBandwidth($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.networkTransmitBandwidth($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.networkReceivePackets($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.networkTransmitPackets($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.networkReceivePacketsDropped($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.networkTransmitPacketsDropped($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
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
              namespace: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              namespace: 'Namespace',
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
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
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

        tsPanel.new('Average Container Bandwidth by Namespace: Received')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.avgContainerReceiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Container Bandwidth by Namespace: Transmitted')
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

        tsPanel.new('IOPS(Reads+Writes)')
        + tsPanel.standardOptions.withUnit('iops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.iopsReadsWrites($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('ThroughPut(Read+Write)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.throughputReadWrite($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Current Storage IO')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.iopsReads($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.iopsWrites($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.iopsReadsWritesCombined($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.throughputRead($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.throughputWrite($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.throughputReadWriteCombined($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
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
              namespace: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              namespace: 'Namespace',
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
                value: $._config.units.network,
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Cluster' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-cluster.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=24, panelHeight=6)),
  },
}
