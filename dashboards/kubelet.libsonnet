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

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local timeSeries = g.panel.timeSeries;
local var = g.dashboard.variable;

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
    'kubelet.json':
      local variables = {
        datasource:
          var.datasource.new('datasource', 'prometheus')
          + var.datasource.withRegex($._config.datasourceFilterRegex)
          + var.datasource.generalOptions.showOnDashboard.withLabelAndValue()
          + var.datasource.generalOptions.withLabel('Data source')
          + {
            current: {
              selected: true,
              text: $._config.datasourceName,
              value: $._config.datasourceName,
            },
          },
        cluster:
          var.query.new('cluster')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            $._config.clusterLabel,
            'up{%(kubeletSelector)s}' % $._config
          )
          + var.query.generalOptions.withLabel('cluster')
          + var.query.refresh.onTime()
          + (
            if $._config.showMultiCluster
            then var.query.generalOptions.showOnDashboard.withLabelAndValue()
            else var.query.generalOptions.showOnDashboard.withNothing()
          )
          + var.query.withSort(type='alphabetical'),
        instance:
          var.query.new('instance')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'instance',
            'up{%(kubeletSelector)s,%(clusterLabel)s="$cluster"}' % $._config,
          )
          + var.query.generalOptions.withLabel('instance')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.selectionOptions.withIncludeAll(true),
      };

      local panels = {
        statRunningKubelets:
          statPanel('Running Kubelets', 'none', 'sum(kubelet_node_name{%(clusterLabel)s="$cluster", %(kubeletSelector)s})' % $._config),
        statRunningPods:
          statPanel('Running Pods', 'none', 'sum(kubelet_running_pods{%(clusterLabel)s="$cluster", %(kubeletSelector)s, instance=~"$instance"})' % $._config),
        statRunningContainers:
          statPanel('Running Containers', 'none', 'sum(kubelet_running_containers{%(clusterLabel)s="$cluster", %(kubeletSelector)s, container_state="running", instance=~"$instance"})' % $._config),
        statActualVolumeCount:
          statPanel('Actual Volume Count', 'none', 'sum(volume_manager_total_volumes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, instance=~"$instance", state="actual_state_of_world"})' % $._config),
        statDesiredVolumeCount:
          statPanel('Desired Volume Count', 'none', 'sum(volume_manager_total_volumes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, instance=~"$instance",state="desired_state_of_world"})' % $._config),

        tsOperationRate:
          tsPanel.new('Operation Rate')
          + tsPanel.standardOptions.withUnit('ops')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'sum(rate(kubelet_runtime_operations_total{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])) by (operation_type, instance)' % $._config)
            + prometheus.withLegendFormat('{{instance}} {{operation_type}}'),
          ]),
        tsOperationErrorRate:
          tsPanel.new('Operation Error Rate')
          + tsPanel.standardOptions.withUnit('ops')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'sum(rate(kubelet_runtime_operations_errors_total{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, operation_type)' % $._config)
            + prometheus.withLegendFormat('{{instance}} {{operation_type}}'),
          ]),
        tsOperationDuration:
          tsPanel.new('Operation Duration 99th quantile')
          + tsPanel.standardOptions.withUnit('s')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(kubelet_runtime_operations_duration_seconds_bucket{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, operation_type, le))' % $._config)
            + prometheus.withLegendFormat('{{instance}} {{operation_type}}'),
          ]),
        tsPodStartRate:
          tsPanel.new('Pod Start Rate')
          + tsPanel.standardOptions.withUnit('ops')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'sum(rate(kubelet_pod_start_duration_seconds_count{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance)' % $._config)
            + prometheus.withLegendFormat('{{instance}} pod'),

            prometheus.new('${datasource}', 'sum(rate(kubelet_pod_worker_duration_seconds_count{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance)' % $._config)
            + prometheus.withLegendFormat('{{instance}} worker'),
          ]),
        tsPodStartDuration:
          tsPanel.new('Pod Start Duration')
          + tsPanel.standardOptions.withUnit('s')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(kubelet_pod_start_duration_seconds_bucket{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, le))' % $._config)
            + prometheus.withLegendFormat('{{instance}} pod'),

            prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(kubelet_pod_worker_duration_seconds_bucket{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, le))' % $._config)
            + prometheus.withLegendFormat('{{instance}} worker'),
          ]),
        tsStorageOperationRate:
          tsPanel.new('Storage Operation Rate')
          + tsPanel.standardOptions.withUnit('ops')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'sum(rate(storage_operation_duration_seconds_count{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, operation_name, volume_plugin)' % $._config)
            + prometheus.withLegendFormat('{{instance}} {{operation_name}} {{volume_plugin}}'),
          ]),
        tsStorageOperationErrorRate:
          tsPanel.new('Storage Operation Error Rate')
          + tsPanel.standardOptions.withUnit('ops')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'sum(rate(storage_operation_duration_seconds_count{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance",status!="success"}[%(grafanaIntervalVar)s])) by (instance, operation_name, volume_plugin)' % $._config)
            + prometheus.withLegendFormat('{{instance}} {{operation_name}} {{volume_plugin}}'),
          ]),
        tsStorageOperationDuration:
          tsPanel.new('Storage Operation Duration 99th quantile')
          + tsPanel.standardOptions.withUnit('s')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(storage_operation_duration_seconds_bucket{%(clusterLabel)s="$cluster", %(kubeletSelector)s, instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, operation_name, volume_plugin, le))' % $._config)
            + prometheus.withLegendFormat('{{instance}} {{operation_name}} {{volume_plugin}}'),
          ]),
        tsCgroupManagerOperationRate:
          tsPanel.new('Cgroup manager operation rate')
          + tsPanel.standardOptions.withUnit('ops')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'sum(rate(kubelet_cgroup_manager_duration_seconds_count{%(clusterLabel)s="$cluster", %(kubeletSelector)s, instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, operation_type)' % $._config)
            + prometheus.withLegendFormat('{{operation_type}}'),
          ]),
        tsCgroupManagerOperationDuration:
          tsPanel.new('Cgroup manager 99th quantile')
          + tsPanel.standardOptions.withUnit('s')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(kubelet_cgroup_manager_duration_seconds_bucket{%(clusterLabel)s="$cluster", %(kubeletSelector)s, instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, operation_type, le))' % $._config)
            + prometheus.withLegendFormat('{{instance}} {{operation_type}}'),
          ]),
        tsPlegRelistRate:
          tsPanel.new('PLEG relist rate')
          + tsPanel.standardOptions.withUnit('ops')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'sum(rate(kubelet_pleg_relist_duration_seconds_count{%(clusterLabel)s="$cluster", %(kubeletSelector)s, instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance)' % $._config)
            + prometheus.withLegendFormat('{{instance}}'),
          ]),
        tsPlegRelistInterval:
          tsPanel.new('PLEG relist interval')
          + tsPanel.standardOptions.withUnit('s')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(kubelet_pleg_relist_interval_seconds_bucket{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, le))' % $._config)
            + prometheus.withLegendFormat('{{instance}}'),
          ]),
        tsPlegRelistDuration:
          tsPanel.new('PLEG relist duration')
          + tsPanel.standardOptions.withUnit('s')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(kubelet_pleg_relist_duration_seconds_bucket{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, le))' % $._config)
            + prometheus.withLegendFormat('{{instance}}'),
          ]),
        tsRpcRate:
          tsPanel.new('RPC rate')
          + tsPanel.standardOptions.withUnit('ops')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",%(kubeletSelector)s, instance=~"$instance",code=~"2.."}[%(grafanaIntervalVar)s]))' % $._config)
            + prometheus.withLegendFormat('2xx'),

            prometheus.new('${datasource}', 'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",%(kubeletSelector)s, instance=~"$instance",code=~"3.."}[%(grafanaIntervalVar)s]))' % $._config)
            + prometheus.withLegendFormat('3xx'),

            prometheus.new('${datasource}', 'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",%(kubeletSelector)s, instance=~"$instance",code=~"4.."}[%(grafanaIntervalVar)s]))' % $._config)
            + prometheus.withLegendFormat('4xx'),

            prometheus.new('${datasource}', 'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",%(kubeletSelector)s, instance=~"$instance",code=~"5.."}[%(grafanaIntervalVar)s]))' % $._config)
            + prometheus.withLegendFormat('5xx'),
          ]),
        tsRequestDuration:
          tsPanel.new('Request duration 99th quantile')
          + tsPanel.standardOptions.withUnit('s')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(rest_client_request_duration_seconds_bucket{%(clusterLabel)s="$cluster",%(kubeletSelector)s, instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, verb, le))' % $._config)
            + prometheus.withLegendFormat('{{instance}} {{verb}}'),
          ]),
        tsMemory:
          tsPanel.new('Memory')
          + tsPanel.standardOptions.withUnit('bytes')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'process_resident_memory_bytes{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}' % $._config)
            + prometheus.withLegendFormat('{{instance}}'),
          ]),
        tsCpu:
          tsPanel.new('CPU usage')
          + tsPanel.standardOptions.withUnit('short')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'rate(process_cpu_seconds_total{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])' % $._config)
            + prometheus.withLegendFormat('{{instance}}'),
          ]),
        tsGoRoutines:
          tsPanel.new('Goroutines')
          + tsPanel.standardOptions.withUnit('short')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'go_goroutines{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}' % $._config)
            + prometheus.withLegendFormat('{{instance}}'),
          ]),
      };

      local rows = [
        {
          panelWidth: 4,
          panelHeight: 7,
          yIndex: 0,
          panels: [
            panels.statRunningKubelets,
            panels.statRunningPods,
            panels.statRunningContainers,
            panels.statActualVolumeCount,
            panels.statDesiredVolumeCount,
          ],
        },

        {
          panelWidth: 12,
          panelHeight: 7,
          yIndex: 7,
          panels: [
            panels.tsOperationRate,
            panels.tsOperationErrorRate,
          ],
        },

        {
          panelWidth: 24,
          panelHeight: 7,
          yIndex: 14,
          panels: [
            panels.tsOperationDuration,
          ],
        },

        {
          panelWidth: 12,
          panelHeight: 7,
          yIndex: 21,
          panels: [
            panels.tsPodStartRate,
            panels.tsPodStartDuration,
          ],
        },

        {
          panelWidth: 12,
          panelHeight: 7,
          yIndex: 28,
          panels: [
            panels.tsStorageOperationRate,
            panels.tsStorageOperationErrorRate,
          ],
        },

        {
          panelWidth: 24,
          panelHeight: 7,
          yIndex: 35,
          panels: [
            panels.tsStorageOperationDuration,
          ],
        },

        {
          panelWidth: 12,
          panelHeight: 7,
          yIndex: 42,
          panels: [
            panels.tsCgroupManagerOperationRate,
            panels.tsCgroupManagerOperationDuration,
          ],
        },

        {
          panelWidth: 12,
          panelHeight: 7,
          yIndex: 49,
          panels: [
            panels.tsPlegRelistRate,
            panels.tsPlegRelistInterval,
          ],
        },

        {
          panelWidth: 24,
          panelHeight: 7,
          yIndex: 56,
          panels: [
            panels.tsPlegRelistDuration,
          ],
        },

        {
          panelWidth: 24,
          panelHeight: 7,
          yIndex: 63,
          panels: [
            panels.tsRpcRate,
          ],
        },

        {
          panelWidth: 24,
          panelHeight: 7,
          yIndex: 70,
          panels: [
            panels.tsRequestDuration,
          ],
        },

        {
          panelWidth: 8,
          panelHeight: 7,
          yIndex: 77,
          panels: [
            panels.tsMemory,
            panels.tsCpu,
            panels.tsGoRoutines,
          ],
        },
      ];

      local rowfunc(row) = [] + g.util.grid.wrapPanels(
        row.panels,
        row.panelWidth,
        row.panelHeight,
        row.yIndex
      );

      g.dashboard.new('%(dashboardNamePrefix)sKubelet' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['kubelet.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.instance])
      + g.dashboard.withPanels(
        std.flatMap(rowfunc, rows),
      ),
  },
}
