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

// Render the real dashboard queries so the PromQL tests cannot drift from the source.
local queries = import '../../dashboards/queries/persistentvolumesusage.libsonnet';
local config = {
  clusterLabel: 'cluster',
  kubeletSelector: 'job="kubelet", metrics_path="/metrics"',
};

local interpolate(expr) =
  std.strReplace(
    std.strReplace(std.strReplace(expr, '$cluster', 'alpha'), '$namespace', 'apps'),
    '$volume',
    'shared'
  );

local input(metric, value, node='node-a', extraLabels='', clusterLabel='cluster') = {
  series: '%s{%s="alpha",namespace="apps",persistentvolumeclaim="shared",job="kubelet",metrics_path="/metrics",instance="%s:10250",node="%s"%s}' % [metric, clusterLabel, node, node, extraLabels],
  values: std.toString(value),
};

local exprTest(expr, value, clusterLabel='cluster') = {
  expr: interpolate(expr),
  eval_time: '0m',
  exp_samples: if value == null then [] else [{
    labels: '{%s="alpha",namespace="apps",persistentvolumeclaim="shared"}' % clusterLabel,
    value: value,
  }],
};

local check(name, inputs, space, inodes, cfg=config) = {
  name: name,
  interval: '1m',
  input_series: inputs,
  promql_expr_test: [
    exprTest(queries.volumeSpaceUsagePercent(cfg), space, cfg.clusterLabel),
    exprTest(queries.volumeInodesUsagePercent(cfg), inodes, cfg.clusterLabel),
  ],
};

std.manifestYamlDoc({
  evaluation_interval: '1m',
  fuzzy_compare: true,
  tests: [
    check('single node volume', [
      input('kubelet_volume_stats_capacity_bytes', 1000),
      input('kubelet_volume_stats_available_bytes', 800),
      input('kubelet_volume_stats_inodes', 1000),
      input('kubelet_volume_stats_inodes_used', 20),
    ], 20, 2),

    // All reporters refer to the same RWX volume. Ties must not select independent
    // node labels, and reporting the volume twice must not double either percentage.
    check('shared volume with equal readings on multiple nodes', [
      input(reading[0], reading[1], node)
      for reading in [
        ['kubelet_volume_stats_capacity_bytes', 1000],
        ['kubelet_volume_stats_available_bytes', 800],
        ['kubelet_volume_stats_inodes', 1000],
        ['kubelet_volume_stats_inodes_used', 20],
      ]
      for node in ['node-a', 'node-b']
    ], 20, 2),

    // Metrics can have different reporting nodes during mount/scrape transitions.
    // Arithmetic must match the PVC identity, not the individual reporter labels.
    check('capacity and usage have different reporting nodes', [
      input('kubelet_volume_stats_capacity_bytes', 1000, 'node-a'),
      input('kubelet_volume_stats_available_bytes', 800, 'node-b'),
      input('kubelet_volume_stats_inodes', 1000, 'node-c'),
      input('kubelet_volume_stats_inodes_used', 20, 'node-d'),
    ], 20, 2),

    // Force the maximum for each operand onto a different node. Independent topk
    // selectors return no matching series even without tied values in this case.
    check('maximum readings belong to different nodes', [
      input('kubelet_volume_stats_capacity_bytes', 1000, 'node-a'),
      input('kubelet_volume_stats_capacity_bytes', 900, 'node-b'),
      input('kubelet_volume_stats_available_bytes', 600, 'node-a'),
      input('kubelet_volume_stats_available_bytes', 800, 'node-b'),
      input('kubelet_volume_stats_inodes', 1000, 'node-a'),
      input('kubelet_volume_stats_inodes', 2000, 'node-b'),
      input('kubelet_volume_stats_inodes_used', 80, 'node-a'),
      input('kubelet_volume_stats_inodes_used', 40, 'node-b'),
    ], 20, 4),

    check('different scrape labels still match the same PVC', [
      input('kubelet_volume_stats_capacity_bytes', 1000, extraLabels=',service="kubelet-a"'),
      input('kubelet_volume_stats_available_bytes', 800, extraLabels=',service="kubelet-b"'),
      input('kubelet_volume_stats_inodes', 1000, extraLabels=',service="kubelet-a"'),
      input('kubelet_volume_stats_inodes_used', 20, extraLabels=',service="kubelet-b"'),
    ], 20, 2),

    check('empty volume', [
      input('kubelet_volume_stats_capacity_bytes', 1000),
      input('kubelet_volume_stats_available_bytes', 1000),
      input('kubelet_volume_stats_inodes', 1000),
      input('kubelet_volume_stats_inodes_used', 0),
    ], 0, 0),

    check('full volume', [
      input('kubelet_volume_stats_capacity_bytes', 1000),
      input('kubelet_volume_stats_available_bytes', 0),
      input('kubelet_volume_stats_inodes', 1000),
      input('kubelet_volume_stats_inodes_used', 1000),
    ], 100, 100),

    check('missing capacity and inode totals remain missing', [
      input('kubelet_volume_stats_available_bytes', 800),
      input('kubelet_volume_stats_inodes_used', 20),
    ], null, null),

    check('missing usage metrics remain missing', [
      input('kubelet_volume_stats_capacity_bytes', 1000),
      input('kubelet_volume_stats_inodes', 1000),
    ], null, null),

    check('custom cluster label', [
      input('kubelet_volume_stats_capacity_bytes', 1000, 'node-a', clusterLabel='k8s_cluster'),
      input('kubelet_volume_stats_available_bytes', 800, 'node-b', clusterLabel='k8s_cluster'),
      input('kubelet_volume_stats_inodes', 1000, 'node-a', clusterLabel='k8s_cluster'),
      input('kubelet_volume_stats_inodes_used', 20, 'node-b', clusterLabel='k8s_cluster'),
    ], 20, 2, config { clusterLabel: 'k8s_cluster' }),
  ],
})
