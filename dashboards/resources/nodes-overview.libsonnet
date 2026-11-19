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

local defaultQueries = import './queries/nodes-overview.libsonnet';
local defaultVariables = import './variables/nodes-overview.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local fieldOverride = g.panel.timeSeries.fieldOverride;
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
    'k8s-resources-nodes-overview.json':
      // Allow overriding queries via $._queries.nodesOverview, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'nodesOverview')
      then $._queries.nodesOverview
      else defaultQueries;

      // Allow overriding variables via $._variables.nodesOverview, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'nodesOverview')
      then $._variables.nodesOverview($._config)
      else defaultVariables.nodesOverview($._config);

      local panels = [
        // Node and pod count over time (dual y-axis)
        tsPanel.new('Node & Pod Count')
        + tsPanel.standardOptions.withUnit('short')
        + tsPanel.standardOptions.withDecimals(0)
        + tsPanel.fieldConfig.defaults.custom.withFillOpacity(0)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.nodeCount($._config),
          )
          + prometheus.withLegendFormat('nodes'),

          prometheus.new(
            '${datasource}',
            queries.podCount($._config),
          )
          + prometheus.withLegendFormat('pods'),
        ])
        + tsPanel.standardOptions.withOverrides([
          fieldOverride.byName.new('pods')
          + fieldOverride.byName.withProperty('custom.axisPlacement', 'right')
          + fieldOverride.byName.withProperty('custom.axisSoftMin', 0),
        ]),

        // Total CPU — allocatable, requests, usage
        tsPanel.new('CPU Usage')
        + tsPanel.standardOptions.withUnit('short')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.cpuAllocatable($._config),
          )
          + prometheus.withLegendFormat('allocatable'),

          prometheus.new(
            '${datasource}',
            queries.cpuRequests($._config),
          )
          + prometheus.withLegendFormat('requests'),

          prometheus.new(
            '${datasource}',
            queries.cpuUsage($._config),
          )
          + prometheus.withLegendFormat('usage'),
        ]),

        // Total Memory — allocatable, requests, usage
        tsPanel.new('Memory Usage')
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.memoryAllocatable($._config),
          )
          + prometheus.withLegendFormat('allocatable'),

          prometheus.new(
            '${datasource}',
            queries.memoryRequests($._config),
          )
          + prometheus.withLegendFormat('requests'),

          prometheus.new(
            '${datasource}',
            queries.memoryUsage($._config),
          )
          + prometheus.withLegendFormat('usage'),
        ]),

        // CPU utilization per node (percentage)
        tsPanel.new('CPU Utilization per Node')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.cpuUtilizationPerNode($._config),
          )
          + prometheus.withLegendFormat('{{node}}'),
        ]),

        // Memory utilization per node (percentage)
        tsPanel.new('Memory Utilization per Node')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.memoryUtilizationPerNode($._config),
          )
          + prometheus.withLegendFormat('{{node}}'),
        ]),

        // Memory compaction re-pack rate per node (direct stall/fail/success + kcompactd wake)
        tsPanel.new('Memory Compaction Re-pack Rate per Node')
        + tsPanel.standardOptions.withUnit('ops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.memoryCompactionStallRatePerNode($._config),
          )
          + prometheus.withLegendFormat('stall: {{node}}'),

          prometheus.new(
            '${datasource}',
            queries.memoryCompactionFailRatePerNode($._config),
          )
          + prometheus.withLegendFormat('fail: {{node}}'),

          prometheus.new(
            '${datasource}',
            queries.memoryCompactionSuccessRatePerNode($._config),
          )
          + prometheus.withLegendFormat('success: {{node}}'),

          prometheus.new(
            '${datasource}',
            queries.memoryCompactionDaemonWakeRatePerNode($._config),
          )
          + prometheus.withLegendFormat('kcompactd wake: {{node}}'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Nodes Overview' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-nodes-overview.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-6h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=24, panelHeight=8)),
  },
}
