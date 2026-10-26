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
    kubeStateMetricsSelector: error 'must provide selector for kube-state-metrics',
    kubeletSelector: error 'must provide selector for kubelet',
    namespaceSelector: null,
    prefixedNamespaceSelector: if self.namespaceSelector != null then self.namespaceSelector + ',' else '',

    // We alert when a disk is expected to fill up in four days. Depending on
    // the data-set it might be useful to change the sampling-time for the
    // prediction
    volumeFullPredictionSampleTime: '6h',

    // thresholds for KubePersistentVolumeFillingUp alerts
    volumeFreeSpacePercentageCritical: '0.03',
    volumeFreeSpacePercentageWarning: '0.15',

    // thresholds for KubePersistentVolumeInodesFillingUp alerts
    volumeFreeInodesPercentageCritical: '0.03',
    volumeFreeInodesPercentageWarning: '0.15',
  },

  prometheusAlerts+:: {
    local additionalGrouping = utils.rejectGroupingLabels(
      $._config.additionalGrouping.alertingRules,
      ['__name__', 'access_mode', 'alertname', 'severity'],
      'storage alerting rules',
      'additionalGrouping.alertingRules'
    ),
    local groupingLabels(labels, excludedAdditionalLabels=[]) =
      utils.groupingLabels(labels, utils.withoutLabels(additionalGrouping, excludedAdditionalLabels)),
    local config = $._config {
      matchingPersistentVolumeClaimAccessMode: groupingLabels([$._config.clusterLabel, 'namespace', 'persistentvolumeclaim'], ['access_mode']),
      matchingPersistentVolumeClaimLabels: groupingLabels([$._config.clusterLabel, 'namespace', 'persistentvolumeclaim'], ['label_excluded_from_alerts']),
    },

    groups+: [
      {
        name: 'kubernetes-storage',
        rules: [
          {
            alert: 'KubePersistentVolumeFillingUp',
            expr: |||
              (
                kubelet_volume_stats_available_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
                  /
                kubelet_volume_stats_capacity_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
              ) < %(volumeFreeSpacePercentageCritical)s
              and
              kubelet_volume_stats_used_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s} > 0
              unless on(%(matchingPersistentVolumeClaimAccessMode)s)
              kube_persistentvolumeclaim_access_mode{%(prefixedNamespaceSelector)s access_mode="ReadOnlyMany"} == 1
              unless on(%(matchingPersistentVolumeClaimLabels)s)
              kube_persistentvolumeclaim_labels{%(prefixedNamespaceSelector)s%(pvExcludedSelector)s} == 1
            ||| % config,
            'for': '1m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: 'The PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} {{ with $labels.%(clusterLabel)s -}} on Cluster {{ . }} {{- end }} is only {{ $value | humanizePercentage }} free.' % $._config,
              summary: 'PersistentVolume is filling up.',
            },
          },
          {
            alert: 'KubePersistentVolumeFillingUp',
            expr: |||
              (
                kubelet_volume_stats_available_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
                  /
                kubelet_volume_stats_capacity_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
              ) < %(volumeFreeSpacePercentageWarning)s
              and
              kubelet_volume_stats_used_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s} > 0
              and
              predict_linear(kubelet_volume_stats_available_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}[%(volumeFullPredictionSampleTime)s], 4 * 24 * 3600) < 0
              unless on(%(matchingPersistentVolumeClaimAccessMode)s)
              kube_persistentvolumeclaim_access_mode{%(prefixedNamespaceSelector)s access_mode="ReadOnlyMany"} == 1
              unless on(%(matchingPersistentVolumeClaimLabels)s)
              kube_persistentvolumeclaim_labels{%(prefixedNamespaceSelector)s%(pvExcludedSelector)s} == 1
            ||| % config,
            'for': '1h',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Based on recent sampling, the PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} {{ with $labels.%(clusterLabel)s -}} on Cluster {{ . }} {{- end }} is expected to fill up within four days. Currently {{ $value | humanizePercentage }} is available.' % $._config,
              summary: 'PersistentVolume is filling up.',
            },
          },
          {
            alert: 'KubePersistentVolumeInodesFillingUp',
            expr: |||
              (
                kubelet_volume_stats_inodes_free{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
                  /
                kubelet_volume_stats_inodes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
              ) < %(volumeFreeInodesPercentageCritical)s
              and
              kubelet_volume_stats_inodes_used{%(prefixedNamespaceSelector)s%(kubeletSelector)s} > 0
              unless on(%(matchingPersistentVolumeClaimAccessMode)s)
              kube_persistentvolumeclaim_access_mode{%(prefixedNamespaceSelector)s access_mode="ReadOnlyMany"} == 1
              unless on(%(matchingPersistentVolumeClaimLabels)s)
              kube_persistentvolumeclaim_labels{%(prefixedNamespaceSelector)s%(pvExcludedSelector)s} == 1
            ||| % config,
            'for': '1m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: 'The PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} {{ with $labels.%(clusterLabel)s -}} on Cluster {{ . }} {{- end }} only has {{ $value | humanizePercentage }} free inodes.' % $._config,
              summary: 'PersistentVolumeInodes are filling up.',
            },
          },
          {
            alert: 'KubePersistentVolumeInodesFillingUp',
            expr: |||
              (
                kubelet_volume_stats_inodes_free{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
                  /
                kubelet_volume_stats_inodes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
              ) < %(volumeFreeInodesPercentageWarning)s
              and
              kubelet_volume_stats_inodes_used{%(prefixedNamespaceSelector)s%(kubeletSelector)s} > 0
              and
              predict_linear(kubelet_volume_stats_inodes_free{%(prefixedNamespaceSelector)s%(kubeletSelector)s}[%(volumeFullPredictionSampleTime)s], 4 * 24 * 3600) < 0
              unless on(%(matchingPersistentVolumeClaimAccessMode)s)
              kube_persistentvolumeclaim_access_mode{%(prefixedNamespaceSelector)s access_mode="ReadOnlyMany"} == 1
              unless on(%(matchingPersistentVolumeClaimLabels)s)
              kube_persistentvolumeclaim_labels{%(prefixedNamespaceSelector)s%(pvExcludedSelector)s} == 1
            ||| % config,
            'for': '1h',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Based on recent sampling, the PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} {{ with $labels.%(clusterLabel)s -}} on Cluster {{ . }} {{- end }} is expected to run out of inodes within four days. Currently {{ $value | humanizePercentage }} of its inodes are free.' % $._config,
              summary: 'PersistentVolumeInodes are filling up.',
            },
          },
          {
            alert: 'KubePersistentVolumeErrors',
            expr: |||
              kube_persistentvolume_status_phase{phase=~"Failed|Pending",%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: 'The persistent volume {{ $labels.persistentvolume }} {{ with $labels.%(clusterLabel)s -}} on Cluster {{ . }} {{- end }} has status {{ $labels.phase }}.' % $._config,
              summary: 'PersistentVolume is having issues with provisioning.',
            },
          },
        ],
      },
    ],
  },
}
