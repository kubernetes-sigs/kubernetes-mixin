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
local var = g.dashboard.variable;
local stat = g.panel.stat;
local ts = g.panel.timeSeries;
local override = ts.standardOptions.override;

{
  _config+:: {
    kubeApiserverSelector: 'job="kube-apiserver"',
  },

  local timeSeries =
    g.panel.timeSeries {
      new(title):
        ts.new(title)
        + ts.options.legend.withShowLegend()
        + ts.options.legend.withAsTable()
        + ts.options.legend.withPlacement('right')
        + ts.options.tooltip.withMode('single')
        + ts.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  local mystatpanel(title, description, query) =
    stat.new(title)
    + stat.panelOptions.withDescription(description)
    + stat.panelOptions.withGridPos(w=6)
    + stat.standardOptions.withUnit('percentunit')
    + stat.standardOptions.withDecimals(3)
    + stat.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
    + stat.queryOptions.withTargets([
      g.query.prometheus.new(
        '${datasource}',
        query,
      ),
    ]),

  local myrequestspanel(title, description, query) =
    timeSeries.new(title)
    + timeSeries.panelOptions.withDescription(description)
    + timeSeries.panelOptions.withGridPos(w=6)
    + timeSeries.standardOptions.withUnit('reqps')
    + timeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
    + timeSeries.fieldConfig.defaults.custom.stacking.withMode('normal')
    + timeSeries.standardOptions.withOverrides([
      override.byRegexp.new('/2../i') + override.byRegexp.withProperty('color', '#56A64B'),
      override.byRegexp.new('/3../i') + override.byRegexp.withProperty('color', '#F2CC0C'),
      override.byRegexp.new('/4../i') + override.byRegexp.withProperty('color', '#3274D9'),
      override.byRegexp.new('/5../i') + override.byRegexp.withProperty('color', '#E02F44'),
    ])
    + timeSeries.queryOptions.withTargets([
      g.query.prometheus.new(
        '${datasource}',
        query
      )
      + g.query.prometheus.withLegendFormat('{{ code }}'),
    ]),

  local myerrorpanel(title, description, query) =
    timeSeries.new(title)
    + timeSeries.panelOptions.withDescription(description)
    + timeSeries.panelOptions.withGridPos(w=6)
    + timeSeries.standardOptions.withUnit('percentunit')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.queryOptions.withTargets([
      g.query.prometheus.new(
        '${datasource}',
        query
      )
      + g.query.prometheus.withLegendFormat('{{ resource }}'),
    ]),

  local mydurationpanel(title, description, query) =
    timeSeries.new(title)
    + timeSeries.panelOptions.withDescription(description)
    + timeSeries.panelOptions.withGridPos(w=6)
    + timeSeries.standardOptions.withUnit('s')
    + timeSeries.queryOptions.withTargets([
      g.query.prometheus.new(
        '${datasource}',
        query
      )
      + g.query.prometheus.withLegendFormat('{{ resource }}'),
    ]),

  grafanaDashboards+:: {
    'apiserver.json':
      local panels = {
        notice:
          g.panel.text.new('Notice')
          + g.panel.text.options.withContent('The SLO (service level objective) and other metrics displayed on this dashboard are for informational purposes only.')
          + g.panel.text.panelOptions.withDescription('The SLO (service level objective) and other metrics displayed on this dashboard are for informational purposes only.')
          + g.panel.text.panelOptions.withGridPos(2, 24, 0, 0),

        availability1d:
          mystatpanel(
            'Availability (%dd) > %.3f%%' % [
              $._config.SLOs.apiserver.days,
              100 * $._config.SLOs.apiserver.target,
            ],
            'How many percent of requests (both read and write) in %d days have been answered successfully and fast enough?' % $._config.SLOs.apiserver.days,
            'apiserver_request:availability%dd{verb="all", %(clusterLabel)s="$cluster"}' % [$._config.SLOs.apiserver.days, $._config.clusterLabel],
          )
          + stat.panelOptions.withGridPos(w=8),

        errorBudget:
          timeSeries.new('Error Budget (%dd) > %.3f%%' % [$._config.SLOs.apiserver.days, 100 * $._config.SLOs.apiserver.target])
          + timeSeries.panelOptions.withDescription('How much error budget is left looking at our %.3f%% availability guarantee?' % (100 * $._config.SLOs.apiserver.target))
          + timeSeries.panelOptions.withGridPos(w=16)
          + timeSeries.standardOptions.withUnit('percentunit')
          + timeSeries.standardOptions.withDecimals(3)
          + timeSeries.fieldConfig.defaults.custom.withFillOpacity(100)
          + timeSeries.queryOptions.withTargets([
            g.query.prometheus.new(
              '${datasource}',
              '100 * (apiserver_request:availability%dd{verb="all", %(clusterLabel)s="$cluster"} - %f)' % [$._config.SLOs.apiserver.days, $._config.clusterLabel, $._config.SLOs.apiserver.target],
            )
            + g.query.prometheus.withLegendFormat('error budget'),
          ]),

        readAvailability:
          mystatpanel(
            'Read Availability (%dd)' % $._config.SLOs.apiserver.days,
            'How many percent of read requests (LIST,GET) in %d days have been answered successfully and fast enough?' % $._config.SLOs.apiserver.days,
            'apiserver_request:availability%dd{verb="read", %(clusterLabel)s="$cluster"}' % [
              $._config.SLOs.apiserver.days,
              $._config.clusterLabel,
            ]
          ),

        readRequests:
          myrequestspanel(
            'Read SLI - Requests',
            'How many read requests (LIST,GET) per second do the apiservers get by code?',
            'sum by (code) (code_resource:apiserver_request_total:rate5m{verb="read", %(clusterLabel)s="$cluster"})' % $._config,
          ),

        readErrors:
          myerrorpanel(
            'Read SLI - Errors',
            'How many percent of read requests (LIST,GET) per second are returned with errors (5xx)?',
            'sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="read",code=~"5..", %(clusterLabel)s="$cluster"}) / sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="read", %(clusterLabel)s="$cluster"})' % $._config
          ),

        readDuration:
          mydurationpanel(
            'Read SLI - Duration',
            'How many seconds is the 99th percentile for reading (LIST|GET) a given resource?',
            'cluster_quantile:apiserver_request_sli_duration_seconds:histogram_quantile{verb="read", %(clusterLabel)s="$cluster"}' % $._config
          ),

        writeAvailability:
          mystatpanel(
            'Write Availability (%dd)' % $._config.SLOs.apiserver.days,
            'How many percent of write requests (POST|PUT|PATCH|DELETE) in %d days have been answered successfully and fast enough?' % $._config.SLOs.apiserver.days,
            'apiserver_request:availability%dd{verb="write", %(clusterLabel)s="$cluster"}' % [$._config.SLOs.apiserver.days, $._config.clusterLabel]
          ),

        writeRequests:
          myrequestspanel(
            'Write SLI - Requests',
            'How many write requests (POST|PUT|PATCH|DELETE) per second do the apiservers get by code?',
            'sum by (code) (code_resource:apiserver_request_total:rate5m{verb="write", %(clusterLabel)s="$cluster"})' % $._config
          ),

        writeErrors:
          myerrorpanel(
            'Write SLI - Errors',
            'How many percent of write requests (POST|PUT|PATCH|DELETE) per second are returned with errors (5xx)?',
            'sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="write",code=~"5..", %(clusterLabel)s="$cluster"}) / sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="write", %(clusterLabel)s="$cluster"})' % $._config
          ),

        writeDuration:
          mydurationpanel(
            'Write SLI - Duration',
            'How many seconds is the 99th percentile for writing (POST|PUT|PATCH|DELETE) a given resource?',
            'cluster_quantile:apiserver_request_sli_duration_seconds:histogram_quantile{verb="write", %(clusterLabel)s="$cluster"}' % $._config
          ),

        workQueueAddRate:
          timeSeries.new('Work Queue Add Rate')
          + timeSeries.panelOptions.withGridPos(w=12)
          + timeSeries.standardOptions.withUnit('ops')
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.options.legend.withShowLegend(false)
          + timeSeries.queryOptions.withTargets([
            g.query.prometheus.new(
              '${datasource}',
              'sum(rate(workqueue_adds_total{%(kubeApiserverSelector)s, instance=~"$instance", %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (instance, name)' % $._config,
            )
            + g.query.prometheus.withLegendFormat('{{instance}} {{name}}'),
          ]),

        workQueueDepth:
          timeSeries.new('Work Queue Depth')
          + timeSeries.panelOptions.withGridPos(w=12)
          + timeSeries.standardOptions.withUnit('short')
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.options.legend.withShowLegend(false)
          + timeSeries.queryOptions.withTargets([
            g.query.prometheus.new(
              '${datasource}',
              'sum(rate(workqueue_depth{%(kubeApiserverSelector)s, instance=~"$instance", %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (instance, name)' % $._config
            )
            + g.query.prometheus.withLegendFormat('{{instance}} {{name}}'),
          ]),

        workQueueLatency:
          timeSeries.new('Work Queue Latency')
          + timeSeries.panelOptions.withGridPos(w=24)
          + timeSeries.standardOptions.withUnit('s')
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.options.legend.withShowLegend()
          + timeSeries.options.legend.withAsTable()
          + timeSeries.options.legend.withPlacement('right')
          + timeSeries.options.legend.withCalcs(['lastNotNull'])
          + timeSeries.queryOptions.withTargets([
            g.query.prometheus.new(
              '${datasource}',
              (if $._config.nativeHistograms
               then 'histogram_quantile(0.99, sum(rate(workqueue_queue_duration_seconds{%(kubeApiserverSelector)s, instance=~"$instance", %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (instance, name))'
               else 'histogram_quantile(0.99, sum(rate(workqueue_queue_duration_seconds_bucket{%(kubeApiserverSelector)s, instance=~"$instance", %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (instance, name, le))') % $._config,
            )
            + g.query.prometheus.withLegendFormat('{{instance}} {{name}}'),
          ]),

        memory:
          timeSeries.new('Memory')
          + timeSeries.panelOptions.withGridPos(w=8)
          + timeSeries.standardOptions.withUnit('bytes')
          + timeSeries.queryOptions.withTargets([
            g.query.prometheus.new(
              '${datasource}',
              'process_resident_memory_bytes{%(kubeApiserverSelector)s,instance=~"$instance", %(clusterLabel)s="$cluster"}' % $._config,
            )
            + g.query.prometheus.withLegendFormat('{{instance}}'),
          ]),

        cpu:
          timeSeries.new('CPU usage')
          + timeSeries.panelOptions.withGridPos(w=8)
          + timeSeries.standardOptions.withUnit('short')
          + timeSeries.standardOptions.withMin(0)
          + timeSeries.queryOptions.withTargets([
            g.query.prometheus.new(
              '${datasource}',
              'rate(process_cpu_seconds_total{%(kubeApiserverSelector)s,instance=~"$instance", %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])' % $._config
            )
            + g.query.prometheus.withLegendFormat('{{instance}}'),
          ]),

        goroutines:
          timeSeries.new('Goroutines')
          + timeSeries.panelOptions.withGridPos(w=8)
          + timeSeries.standardOptions.withUnit('short')
          + timeSeries.queryOptions.withTargets([
            g.query.prometheus.new(
              '${datasource}',
              'go_goroutines{%(kubeApiserverSelector)s,instance=~"$instance", %(clusterLabel)s="$cluster"}' % $._config
            )
            + g.query.prometheus.withLegendFormat('{{instance}}'),
          ]),

      };

      local variables = {
        datasource:
          var.datasource.new('datasource', 'prometheus')
          + var.datasource.withRegex($._config.datasourceFilterRegex)
          + var.datasource.generalOptions.showOnDashboard.withLabelAndValue()
          + var.datasource.generalOptions.withLabel('Data source')
          + {
            // FIXME: upstream a fix for this
            // withCurrent doesn't seem to work well with datasource variable
            //var.datasource.generalOptions.withCurrent($._config.datasourceName)
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
            'up{%(kubeApiserverSelector)s}' % $._config,
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
            'up{%(kubeApiserverSelector)s, %(clusterLabel)s="$cluster"}' % $._config,
          )
          + var.query.refresh.onTime()
          + var.query.selectionOptions.withIncludeAll()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),
      };

      g.dashboard.new('%(dashboardNamePrefix)sAPI server' % $._config.grafanaK8s)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withVariables([
        variables.datasource,
        variables.cluster,
        variables.instance,
      ])
      + g.dashboard.withPanels(
        [panels.notice]
        + g.util.grid.wrapPanels(  // calculates the xy and sets the height
          [
            panels.availability1d,
            panels.errorBudget,

            panels.readAvailability,
            panels.readRequests,
            panels.readErrors,
            panels.readDuration,

            panels.writeAvailability,
            panels.writeRequests,
            panels.writeErrors,
            panels.writeDuration,

            panels.workQueueAddRate,
            panels.workQueueDepth,
            panels.workQueueLatency,

            panels.memory,
            panels.cpu,
            panels.goroutines,
          ],
          panelHeight=7,
          startY=2,
        )
      ),
  },
}
