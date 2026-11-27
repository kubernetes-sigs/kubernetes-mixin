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

local defaultQueries = import './queries/workload.libsonnet';
local defaultVariables = import './variables/workload.libsonnet';
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
    'k8s-resources-workload.json':
      // Allow overriding queries via $._queries.workload, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'workload')
      then $._queries.workload
      else defaultQueries;

      // Allow overriding variables via $._variables.workload, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'workload')
      then $._variables.workload($._config)
      else defaultVariables.workload($._config);

      local links = {
        pod: {
          title: 'Drill down to pods',
          url: '%(prefix)s/d/%(uid)s?${datasource:queryparam}&var-cluster=$cluster&var-namespace=$namespace&var-pod=${__data.fields.Pod}' % {
            uid: $._config.grafanaDashboardIDs['k8s-resources-pod.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local cpuUsageQuery = queries.cpuUsage($._config);
      local cpuRequestsQuery = queries.cpuRequests($._config);
      local cpuLimitsQuery = queries.cpuLimits($._config);
      local cpuThrottlingQuery = queries.cpuThrottling($._config);
      local cpuThrottledSecondsQuery = queries.cpuThrottledSeconds($._config);

      local memUsageQuery = queries.memUsage($._config);
      local memRequestsQuery = queries.memRequests($._config);
      local memLimitsQuery = queries.memLimits($._config);

      local networkColumns = queries.networkColumns($._config);

      local panels = [
        tsPanel.new('CPU Usage')
        + tsPanel.gridPos.withW(24)
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', cpuUsageQuery)
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('CPU Throttling')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', cpuThrottlingQuery)
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
          prometheus.new('${datasource}', cpuUsageQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuRequestsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuUsageQuery + '/' + cpuRequestsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuLimitsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuUsageQuery + '/' + cpuLimitsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuThrottlingQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuThrottledSecondsQuery)
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
              pod: 7,
              'Value #A': 8,
              'Value #B': 9,
              'Value #C': 10,
              'Value #D': 11,
              'Value #E': 12,
              'Value #F': 13,
              'Value #G': 14,
            },
            renameByName: {
              pod: 'Pod',
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

        tsPanel.new('Memory Usage')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', memUsageQuery)
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Memory Quota')
        + table.gridPos.withW(24)
        + table.standardOptions.withUnit('bytes')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', memUsageQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', memRequestsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', memUsageQuery + '/' + memRequestsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', memLimitsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', memUsageQuery + '/' + memLimitsQuery)
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
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              pod: 8,
              'Value #A': 9,
              'Value #B': 10,
              'Value #C': 11,
              'Value #D': 12,
              'Value #E': 13,
            },
            renameByName: {
              pod: 'Pod',
              'Value #A': 'Memory Usage',
              'Value #B': 'Memory Requests',
              'Value #C': 'Memory Requests %',
              'Value #D': 'Memory Limits',
              'Value #E': 'Memory Limits %',
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

        table.new('Current Network Usage')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', networkColumns[0])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', networkColumns[1])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', networkColumns[2])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', networkColumns[3])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', networkColumns[4])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', networkColumns[5])
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

        tsPanel.new('Average Container Bandwidth by Pod: Received')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.avgContainerReceiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Container Bandwidth by Pod: Transmitted')
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

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Workload' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-workload.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.workload_type, variables.workload])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=7)),
  },
}
