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

// Generation-level regression tests for configurations the mixin has to keep supporting.
// Evaluated by `make config-test`, where a failed assertion fails the build.

local mixin = import '../mixin.libsonnet';

local withApiserverWindows(windows) = mixin {
  _config+:: {
    SLOs+: {
      apiserver+: {
        windows: windows,
      },
    },
  },
};

local groupRules(groups, name) =
  local matching = [group.rules for group in groups if group.name == name];
  if std.length(matching) == 0 then error 'no group named %s' % name else matching[0];

local recordNames(rules) = std.set([rule.record for rule in rules]);

local averagedRecords(rules) = std.set([
  rule.record
  for rule in rules
  if std.length(std.findSubstr('avg_over_time', rule.expr)) > 0
]);

// An empty window list disables the apiserver SLOs. It has to keep emitting no burn rate
// rules and no alerts, rather than failing generation on the empty list.
local noWindows = withApiserverWindows([]);
assert groupRules(noWindows.prometheusRules.groups, 'kube-apiserver-burnrate.rules') == [];
assert groupRules(noWindows.prometheusAlerts.groups, 'kube-apiserver-slos') == [];

// Windows are ordered by duration, so every Prometheus duration literal has to parse:
// sub-second units, units coarser than a day, and compound values.
local exoticWindows = withApiserverWindows([
  { severity: 'critical', 'for': '2m', long: '1m30s', short: '500ms', factor: 14.4 },
  { severity: 'warning', 'for': '3h', long: '2w', short: '1d12h', factor: 1 },
]);
local exoticRules = groupRules(exoticWindows.prometheusRules.groups, 'kube-apiserver-burnrate.rules');

// The shortest window carries the intermediate series, and only windows longer than the
// longest short window are averaged from them.
assert std.member(recordNames(exoticRules), 'cluster_verb:apiserver_request_sli_bad_events:rate500ms');
assert std.member(recordNames(exoticRules), 'cluster_verb:apiserver_request_sli_events:rate500ms');
assert averagedRecords(exoticRules) == std.set(['apiserver_request:burnrate2w']);

// Opting into nativeHistograms replaces all classic _bucket histogram_quantile queries across
// recording rules, alerts, and dashboards with native histogram expressions.
local histogramQuantileExprs(exprs) = [
  expr
  for expr in exprs
  if std.length(std.findSubstr('histogram_quantile(', expr)) > 0
];

local ruleExprs(groups) = [
  rule.expr
  for group in groups
  for rule in group.rules
];

local dashboardTargetExprs(dashboard) =
  local panels =
    (if 'panels' in dashboard then dashboard.panels else []) +
    (if 'rows' in dashboard then [p for r in dashboard.rows for p in r.panels] else []);
  [
    target.expr
    for panel in panels
    if 'targets' in panel
    for target in panel.targets
    if 'expr' in target
  ];

local histogramDashboards = [
  'apiserver.json',
  'controller-manager.json',
  'kubelet.json',
  'proxy.json',
  'scheduler.json',
];

local isNativeHistogramQuantile(expr) =
  std.findSubstr('_bucket', expr) == [] &&
  std.findSubstr('le)', expr) == [] &&
  std.findSubstr('le,', expr) == [];

local classicRuleExprs = histogramQuantileExprs(ruleExprs(mixin.prometheusRules.groups));
local classicAlertExprs = histogramQuantileExprs(ruleExprs(mixin.prometheusAlerts.groups));
local classicDashboardAllExprs = [
  dashboardTargetExprs(mixin.grafanaDashboards[d])
  for d in histogramDashboards
];
local classicDashboardExprs = [
  histogramQuantileExprs(exprs)
  for exprs in classicDashboardAllExprs
];

assert std.length(classicRuleExprs) == 14;
assert std.all([std.length(std.findSubstr('_bucket', expr)) > 0 for expr in classicRuleExprs]);
assert std.length(classicAlertExprs) == 3;
assert std.all([std.length(std.findSubstr('_bucket', expr)) > 0 for expr in classicAlertExprs]);
assert [std.length(exprs) for exprs in classicDashboardExprs] == [1, 3, 8, 4, 6];
assert std.length([
  expr
  for exprs in classicDashboardAllExprs
  for expr in exprs
  if std.length(std.findSubstr('_count{', expr)) > 0
]) == 11;

local withNativeHistograms = mixin {
  _config+:: {
    nativeHistograms: true,
  },
};
local nativeRuleExprs = histogramQuantileExprs(ruleExprs(withNativeHistograms.prometheusRules.groups));
local nativeAlertExprs = histogramQuantileExprs(ruleExprs(withNativeHistograms.prometheusAlerts.groups));
local nativeDashboardAllExprs = [
  dashboardTargetExprs(withNativeHistograms.grafanaDashboards[d])
  for d in histogramDashboards
];
local nativeDashboardExprs = [
  histogramQuantileExprs(exprs)
  for exprs in nativeDashboardAllExprs
];

assert std.length(nativeRuleExprs) == 14;
assert std.all([isNativeHistogramQuantile(expr) for expr in nativeRuleExprs]);
assert std.length(nativeAlertExprs) == 3;
assert std.all([isNativeHistogramQuantile(expr) for expr in nativeAlertExprs]);
assert [std.length(exprs) for exprs in nativeDashboardExprs] == [1, 3, 8, 4, 6];
assert std.all([
  isNativeHistogramQuantile(expr)
  for exprs in nativeDashboardExprs
  for expr in exprs
]);
assert std.all([
  std.findSubstr('_bucket', expr) == [] && std.findSubstr('_count{', expr) == []
  for exprs in nativeDashboardAllExprs
  for expr in exprs
]);
assert std.length(
  std.findSubstr(
    'histogram_count(apiserver_client_certificate_expiration_seconds',
    std.manifestJsonEx(groupRules(withNativeHistograms.prometheusAlerts.groups, 'kubernetes-system-apiserver'), '  ')
  )
) > 0;

true
