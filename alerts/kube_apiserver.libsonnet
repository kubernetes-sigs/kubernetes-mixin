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

local utils = import '../lib/utils.libsonnet';

{
  _config+:: {
    kubeApiserverSelector: error 'must provide selector for kube-apiserver',

    certExpirationWarningSeconds: 7 * 24 * 3600,
    certExpirationCriticalSeconds: 1 * 24 * 3600,
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kube-apiserver-slos',
        rules: [
          {
            alert: 'KubeAPIErrorBudgetBurn',
            expr: |||
              sum by(%s) (apiserver_request:burnrate%s) > (%.2f * %.5f)
              and on(%s)
              sum by(%s) (apiserver_request:burnrate%s) > (%.2f * %.5f)
            ||| % [
              $._config.clusterLabel,
              w.long,
              w.factor,
              (1 - $._config.SLOs.apiserver.target),
              $._config.clusterLabel,
              $._config.clusterLabel,
              w.short,
              w.factor,
              (1 - $._config.SLOs.apiserver.target),
            ],
            labels: {
              severity: w.severity,
              short: '%(short)s' % w,
              long: '%(long)s' % w,
            },
            annotations: {
              description: 'The Kube API server is burning too much error budget%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'The Kube API server is burning too much error budget.',
            },
            'for': '%(for)s' % w,
          }
          for w in $._config.SLOs.apiserver.windows
        ],
      },
      {
        name: 'kubernetes-system-apiserver',
        rules: [
          {
            alert: 'KubeClientCertificateExpiration',
            expr: |||
              histogram_quantile(0.01, sum without (%(namespaceLabel)s, service, endpoint) (rate(apiserver_client_certificate_expiration_seconds_bucket{%(kubeApiserverSelector)s}[5m]))) < %(certExpirationWarningSeconds)s
              and
              on(job, %(clusterLabel)s, instance) apiserver_client_certificate_expiration_seconds_count{%(kubeApiserverSelector)s} > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'A client certificate used to authenticate to kubernetes apiserver is expiring in less than %s%s.' % [
                (utils.humanizeSeconds($._config.certExpirationWarningSeconds)),
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Client certificate is about to expire.',
            },
          },
          {
            alert: 'KubeClientCertificateExpiration',
            expr: |||
              histogram_quantile(0.01, sum without (%(namespaceLabel)s, service, endpoint) (rate(apiserver_client_certificate_expiration_seconds_bucket{%(kubeApiserverSelector)s}[5m]))) < %(certExpirationCriticalSeconds)s
              and
              on(job, %(clusterLabel)s, instance) apiserver_client_certificate_expiration_seconds_count{%(kubeApiserverSelector)s} > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: 'A client certificate used to authenticate to kubernetes apiserver is expiring in less than %s%s.' % [
                (utils.humanizeSeconds($._config.certExpirationCriticalSeconds)),
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Client certificate is about to expire.',
            },
          },
          {
            alert: 'KubeAggregatedAPIErrors',
            expr: |||
              sum by(%(clusterLabel)s, instance, name, reason)(increase(aggregator_unavailable_apiservice_total{%(kubeApiserverSelector)s}[1m])) > 0
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Kubernetes aggregated API {{ $labels.instance }}/{{ $labels.name }} has reported {{ $labels.reason }} errors%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubernetes aggregated API has reported errors.',
            },
          },
          {
            alert: 'KubeAggregatedAPIDown',
            expr: |||
              (1 - max by(name, namespace, %(clusterLabel)s)(avg_over_time(aggregator_unavailable_apiservice{%(kubeApiserverSelector)s}[10m]))) * 100 < 85
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Kubernetes aggregated API {{ $labels.name }}/{{ $labels.namespace }} has been only {{ $value | humanize }}%% available over the last 10m%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubernetes aggregated API is down.',
            },
          },
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeAPI',
            selector:: $._config.kubeApiserverSelector,
          },
          (import '../lib/instance_unreachable_alert.libsonnet') {
            componentName:: 'KubeAPI',
            selector:: $._config.kubeApiserverSelector,
          },
          {
            alert: 'KubeAPITerminatedRequests',
            // APF and max-inflight record dropped 429s in both counters. Keep
            // non-429 terminations in the denominator for timeout paths that
            // may not have reached the request_total instrumentation yet.
            expr: |||
              sum by(%(clusterLabel)s) (rate(apiserver_request_terminations_total{%(kubeApiserverSelector)s}[10m]))
              /
              (
                sum by(%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s}[10m]))
                +
                (
                  sum by(%(clusterLabel)s) (rate(apiserver_request_terminations_total{%(kubeApiserverSelector)s,code!="429"}[10m]))
                  or on(%(clusterLabel)s)
                  0 * sum by(%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s}[10m]))
                )
              ) > 0.20
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'The kubernetes apiserver has terminated {{ $value | humanizePercentage }} of its incoming requests%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'The kubernetes apiserver has terminated {{ $value | humanizePercentage }} of its incoming requests.',
            },
            'for': '5m',
          },
        ],
      },
    ],
  },
}
