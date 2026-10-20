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

{
  _config+:: {
    SLOs: {
      apiserver: {
        days: 30,  // The number of days we alert on burning too much error budget for.
        target: 0.99,  // The target percentage of availability between 0-1. (0.99 = 99%, 0.999 = 99.9%)

        // Only change these windows when you really understand multi burn rate errors.
        // Even though you can change the days above (which will change availability calculations)
        // these windows will alert on a 30 days sliding window. We're looking into basing these windows on the given days too.
        windows: [
          { severity: 'critical', 'for': '2m', long: '1h', short: '5m', factor: 14.4 },
          { severity: 'critical', 'for': '15m', long: '6h', short: '30m', factor: 6 },
          { severity: 'warning', 'for': '1h', long: '1d', short: '2h', factor: 3 },
          { severity: 'warning', 'for': '3h', long: '3d', short: '6h', factor: 1 },
        ],
      },
    },

    // Selectors are inserted between {} in Prometheus queries.
    cadvisorSelector: 'job="cadvisor"',
    kubeletSelector: 'job="kubelet"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    kubeSchedulerSelector: 'job="kube-scheduler"',
    kubeControllerManagerSelector: 'job="kube-controller-manager"',
    kubeApiserverSelector: 'job="kube-apiserver"',
    kubeProxySelector: 'job="kube-proxy"',
    podLabel: 'pod',
    hostNetworkInterfaceSelector: 'device!~"veth.+"',
    hostMountpointSelector: 'mountpoint="/"',
    windowsExporterSelector: 'job="kubernetes-windows-exporter"',
    containerfsSelector: 'container!=""',

    // List of labels to join for different type of metrics
    // Only works if your environment has the labels kube_%s_labels (e.g. kube_pod_labels) available.
    common_join_labels: [],
    pods_join_labels: $._config.common_join_labels,
    statefulsets_join_labels: $._config.common_join_labels,
    deployments_join_labels: $._config.common_join_labels,
    daemonsets_join_labels: $._config.common_join_labels,
    horizontalpodautoscalers_join_labels: $._config.common_join_labels,
    jobs_join_labels: $._config.common_join_labels,

    // Grafana dashboard IDs are necessary for stable links for dashboards
    grafanaDashboardIDs: {
      'apiserver.json': std.md5('apiserver.json'),
      'cluster-total.json': std.md5('cluster-total.json'),
      'controller-manager.json': std.md5('controller-manager.json'),
      'k8s-resources-cluster.json': std.md5('k8s-resources-cluster.json'),
      'k8s-resources-multicluster.json': std.md5('k8s-resources-multicluster.json'),
      'k8s-resources-namespace.json': std.md5('k8s-resources-namespace.json'),
      'k8s-resources-node.json': std.md5('k8s-resources-node.json'),
      'k8s-resources-nodes-overview.json': std.md5('k8s-resources-nodes-overview.json'),
      'k8s-resources-pod.json': std.md5('k8s-resources-pod.json'),
      'k8s-resources-windows-cluster.json': std.md5('k8s-resources-windows-cluster.json'),
      'k8s-resources-windows-namespace.json': std.md5('k8s-resources-windows-namespace.json'),
      'k8s-resources-windows-pod.json': std.md5('k8s-resources-windows-pod.json'),
      'k8s-resources-workload.json': std.md5('k8s-resources-workload.json'),
      'k8s-resources-workloads-namespace.json': std.md5('k8s-resources-workloads-namespace.json'),
      'k8s-windows-cluster-rsrc-use.json': std.md5('k8s-windows-cluster-rsrc-use.json'),
      'k8s-windows-node-rsrc-use.json': std.md5('k8s-windows-node-rsrc-use.json'),
      'kubelet.json': std.md5('kubelet.json'),
      'namespace-by-pod.json': std.md5('namespace-by-pod.json'),
      'namespace-by-workload.json': std.md5('namespace-by-workload.json'),
      'persistentvolumesusage.json': std.md5('persistentvolumesusage.json'),
      'pod-total.json': std.md5('pod-total.json'),
      'proxy.json': std.md5('proxy.json'),
      'scheduler.json': std.md5('scheduler.json'),
      'workload-total.json': std.md5('workload-total.json'),
    },

    // Support for Grafana 7.2+ `$__rate_interval` instead of `$__interval`
    grafana72: true,
    grafanaIntervalVar: if self.grafana72 then '$__rate_interval' else '$__interval',

    // Config for the Grafana dashboards in the Kubernetes Mixin
    grafanaK8s: {
      dashboardNamePrefix: 'Kubernetes / ',
      dashboardTags: ['kubernetes-mixin'],

      // For links between grafana dashboards, you need to tell us if your grafana
      // servers under some non-root path.
      linkPrefix: '',

      // The default refresh time for all dashboards, default to 10s
      refresh: '10s',
      minimumTimeInterval: '1m',

      // Timezone for Grafana dashboards:: UTC, browser, ...
      grafanaTimezone: 'UTC',

      // Add a container-restarts annotation to dashboards containing pods.
      // Set to false to generate the dashboards without it.
      containerRestartAnnotation: true,

      // Whether the container-restarts annotation is enabled by default in each dashboard
      containerRestartAnnotationEnable: true,
    },

    // Units for panels
    units: {
      // Use 'bps' for bits per second (SI), or 'binBps' for bytes per second (IEC).
      network: 'bps',

      // Use a multiplier of 8 when using a "bits" unit (e.g. 'bps'), or 1 when using a "bytes" unit (e.g. 'binBps').
      networkMultiplier: 8,

      // Returns "Bytes" if networkMultiplier is 1, or "Bits" if networkMultiplier is 8
      networkUnitLabel: if self.networkMultiplier == 1 then 'Bytes' else 'Bits',
    },

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: false,
    clusterLabel: 'cluster',

    namespaceLabel: 'namespace',

    // Default datasource name
    datasourceName: 'default',

    // Datasource instance filter regex
    datasourceFilterRegex: '',

    // This list of filesystem is referenced in various expressions.
    fstypes: ['ext[234]', 'btrfs', 'xfs', 'zfs'],
    fstypeSelector: 'fstype=~"%s"' % std.join('|', self.fstypes),

    // This list of disk device names is referenced in various expressions.
    diskDevices: ['mmcblk.p.+', 'nvme.+', 'rbd.+', 'sd.+', 'vd.+', 'xvd.+', 'dm-.+', 'dasd.+'],
    diskDeviceSelector: 'device=~"(/dev.+)|%s"' % std.join('|', self.diskDevices),

    // Certain workloads (e.g. KubeVirt/CDI) will fully utilise the persistent volume they claim
    // the size of the PV will never grow since they consume the entirety of the volume by design.
    // This selector allows an admin to 'pre-mark' the PVC of such a workload (or for any other use case)
    // so that specific storage alerts will not fire.With the default selector, adding a label `excluded-from-alerts: 'true'`
    // to the PVC will have the desired effect.
    pvExcludedSelector: 'label_excluded_from_alerts="true"',

    // Default timeout value for k8s Jobs. The jobs which are active beyond this duration would trigger KubeJobNotCompleted alert.
    kubeJobTimeoutDuration: 12 * 60 * 60,

    // This selector allows an admin to 'pre-mark' a Job (e.g. a long-running batch/Spark job)
    // so that the KubeJobNotCompleted alert will not fire for it. With the default selector,
    // adding a label `excluded-from-alerts: 'true'` to the Job will have the desired effect.
    kubeJobExcludedSelector: 'label_excluded_from_alerts="true"',

    // Controls workload_type label value format: false = lowercase, true = PascalCase
    usePascalCaseForWorkloadTypeLabelValues: false,
  },
}
