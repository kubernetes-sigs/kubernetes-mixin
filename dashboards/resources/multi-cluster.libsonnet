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

local defaultQueries = import './queries/multi-cluster.libsonnet';
local defaultVariables = import './variables/multi-cluster.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
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
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  grafanaDashboards+::
    if $._config.showMultiCluster then {
      'k8s-resources-multicluster.json':
        // Allow overriding queries via $._queries.multiCluster, otherwise use default
        local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'multiCluster')
        then $._queries.multiCluster
        else defaultQueries;

        // Allow overriding variables via $._variables.multiCluster, otherwise use default
        local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'multiCluster')
        then $._variables.multiCluster($._config)
        else defaultVariables.multiCluster($._config);

        local links = {
          cluster: {
            title: 'Drill down',
            url: '%(prefix)s/d/%(uid)s?${datasource:queryparam}&var-cluster=${__data.fields.Cluster}' % {
              uid: $._config.grafanaDashboardIDs['k8s-resources-cluster.json'],
              prefix: $._config.grafanaK8s.linkPrefix,
            },
          },
        };

        local panels = {
          highlights: [
            statPanel(
              'CPU Utilisation',
              'none',
              queries.cpuUtilisation($._config)
            ),

            statPanel(
              'CPU Requests Commitment',
              'percentunit',
              queries.cpuRequestsCommitment($._config)
            ),

            statPanel(
              'CPU Limits Commitment',
              'percentunit',
              queries.cpuLimitsCommitment($._config)
            ),

            statPanel(
              'Memory Utilisation',
              'percentunit',
              queries.memoryUtilisation($._config)
            ),

            statPanel(
              'Memory Requests Commitment',
              'percentunit',
              queries.memoryRequestsCommitment($._config)
            ),

            statPanel(
              'Memory Limits Commitment',
              'percentunit',
              queries.memoryLimitsCommitment($._config)
            ),
          ],

          cpuUsage: [
            tsPanel.new('CPU Usage')
            + tsPanel.queryOptions.withTargets([
              prometheus.new('${datasource}', queries.cpuUsageByCluster($._config))
              + prometheus.withLegendFormat('__auto'),
            ]),
          ],

          cpuQuota: [
            g.panel.table.new('CPU Quota')
            + g.panel.table.queryOptions.withTargets([
              prometheus.new('${datasource}', queries.cpuUsageByCluster($._config))
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', queries.cpuRequestsByCluster($._config))
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', queries.cpuUsageVsRequests($._config))
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', queries.cpuLimitsByCluster($._config))
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', queries.cpuUsageVsLimits($._config))
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
            ])
            + g.panel.table.queryOptions.withTransformations([
              g.panel.table.queryOptions.transformation.withId('joinByField')
              + g.panel.table.queryOptions.transformation.withOptions({
                byField: std.format('%s', $._config.clusterLabel),
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
                },
                indexByName: {
                  'Time 1': 0,
                  'Time 2': 1,
                  'Time 3': 2,
                  'Time 4': 3,
                  'Time 5': 4,
                  [$._config.clusterLabel]: 5,
                  'Value #A': 6,
                  'Value #B': 7,
                  'Value #C': 8,
                  'Value #D': 9,
                  'Value #E': 10,
                },
                renameByName: {
                  [$._config.clusterLabel]: 'Cluster',
                  'Value #A': 'CPU Usage',
                  'Value #B': 'CPU Requests',
                  'Value #C': 'CPU Usage/Requests %',
                  'Value #D': 'CPU Limits',
                  'Value #E': 'CPU Usage/Limits %',
                },
              }),
            ])

            + g.panel.table.standardOptions.withOverrides([
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
                  options: 'Cluster',
                },
                properties: [
                  {
                    id: 'links',
                    value: [links.cluster],
                  },
                ],
              },
            ]),
          ],

          memoryUsage: [
            tsPanel.new('Memory Usage (w/o cache)')
            + tsPanel.standardOptions.withUnit('bytes')
            + tsPanel.queryOptions.withTargets([
              // Not using container_memory_usage_bytes here because that includes page cache
              prometheus.new('${datasource}', queries.memoryUsageByCluster($._config))
              + prometheus.withLegendFormat('__auto'),
            ]),
          ],

          memoryRequests: [
            g.panel.table.new('Memory Requests by Cluster')
            + g.panel.table.standardOptions.withUnit('bytes')
            + g.panel.table.queryOptions.withTargets([
              prometheus.new('${datasource}', queries.memoryUsageByCluster($._config))
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', queries.memoryRequestsByCluster($._config))
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', queries.memoryUsageVsRequests($._config))
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', queries.memoryLimitsByCluster($._config))
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', queries.memoryUsageVsLimits($._config))
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
            ])
            + g.panel.table.queryOptions.withTransformations([
              g.panel.table.queryOptions.transformation.withId('joinByField')
              + g.panel.table.queryOptions.transformation.withOptions({
                byField: std.format('%s', $._config.clusterLabel),
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
                },
                indexByName: {
                  'Time 1': 0,
                  'Time 2': 1,
                  'Time 3': 2,
                  'Time 4': 3,
                  'Time 5': 4,
                  [$._config.clusterLabel]: 5,
                  'Value #A': 6,
                  'Value #B': 7,
                  'Value #C': 8,
                  'Value #D': 9,
                  'Value #E': 10,
                },
                renameByName: {
                  [$._config.clusterLabel]: 'Cluster',
                  'Value #A': 'Memory Usage',
                  'Value #B': 'Memory Requests',
                  'Value #C': 'Memory Usage/Requests %',
                  'Value #D': 'Memory Limits',
                  'Value #E': 'Memory Usage/Limits %',
                },
              }),
            ])

            + g.panel.table.standardOptions.withOverrides([
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
                  options: 'Cluster',
                },
                properties: [
                  {
                    id: 'links',
                    value: [links.cluster],
                  },
                ],
              },
            ]),
          ],
        };

        g.dashboard.new('%(dashboardNamePrefix)sCompute Resources /  Multi-Cluster' % $._config.grafanaK8s)
        + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-multicluster.json'])
        + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
        + g.dashboard.withEditable(false)
        + g.dashboard.time.withFrom('now-1h')
        + g.dashboard.time.withTo('now')
        + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
        + g.dashboard.withVariables([variables.datasource])
        + g.dashboard.withPanels(
          g.util.grid.wrapPanels(panels.highlights, panelWidth=4, panelHeight=3, startY=0)
          + g.util.grid.wrapPanels(panels.cpuUsage, panelWidth=24, panelHeight=7, startY=1)
          + g.util.grid.wrapPanels(panels.cpuQuota, panelWidth=24, panelHeight=7, startY=2)
          + g.util.grid.wrapPanels(panels.memoryUsage, panelWidth=24, panelHeight=7, startY=3)
          + g.util.grid.wrapPanels(panels.memoryRequests, panelWidth=24, panelHeight=7, startY=4)
        ),
    } else {},
}
