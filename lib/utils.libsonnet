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
  mapRuleGroups(f): {
    groups: [
      group {
        rules: [
          f(rule)
          for rule in super.rules
        ],
      }
      for group in super.groups
    ],
  },

  groupingLabels(queryLabels, additionalLabels):
    local labels = std.foldl(
      function(labels, label)
        if std.member(labels, label) then labels else labels + [label],
      queryLabels + additionalLabels,
      []
    );
    std.join(', ', labels),

  withoutLabels(labels, excludedLabels):
    [label for label in labels if !std.member(excludedLabels, label)],

  humanizeSeconds(s)::
    if s > 60 * 60 * 24
    then '%.1f days' % (s / 60 / 60 / 24)
    else '%.1f hours' % (s / 60 / 60),

  // Handle adding `group left` to join labels into rule by wrapping the rule in () * on(xxx) group_left(xxx) kube_xxx_labels
  // If kind of rule is not defined try to detect rule type by alert name
  wrap_rule_for_labels(rule, config):
    // Detect Kind of rule from name unless hidden `kind field is passed in the rule`
    local kind =
      if 'kind' in rule then rule.kind
      // Handle Alerts
      else if std.objectHas(rule, 'alert') then
        if std.startsWith(rule.alert, 'KubePod') then 'pod'
        else if std.startsWith(rule.alert, 'KubeContainer') then 'pod'
        else if std.startsWith(rule.alert, 'KubeStateful') then 'statefulset'
        else if std.startsWith(rule.alert, 'KubeDeploy') then 'deployment'
        else if std.startsWith(rule.alert, 'KubeDaemon') then 'daemonset'
        else if std.startsWith(rule.alert, 'KubeHpa') then 'horizontalpodautoscaler'
        else if std.startsWith(rule.alert, 'KubeJob') then 'job'
        else 'none'
      else 'none';

    local labels = {
      join_labels: config['%ss_join_labels' % kind],
      // since the label 'job' is reserved, the resource with kind Job uses the label 'job_name' instead
      on_labels: ['%s' % (if kind == 'job' then 'job_name' else kind), '%s' % config.namespaceLabel, '%s' % config.clusterLabel],
      metric: 'kube_%s_labels' % kind,
    };

    // Failed to identify kind - return raw rule
    if kind == 'none' then rule
    // No join labels passed in the config - return raw rule
    else if std.length(labels.join_labels) == 0 then rule
    // Wrap expr with join group left
    else
      rule {
        local expr = super.expr,
        expr: '(%(expr)s) * on (%(on)s) group_left(%(join)s) %(metric)s' % {
          expr: expr,
          on: std.join(',', labels.on_labels),
          join: std.join(',', labels.join_labels),
          metric: labels.metric,
        },
      },

  // if showMultiCluster is true in config, return the string, otherwise return an empty string
  ifShowMultiCluster(config, string)::
    if config.showMultiCluster then string else '',
}
