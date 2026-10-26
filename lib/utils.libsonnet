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

  validateGroupingLabels(labels, groupingConfig):
    local isLetter(char) =
      (char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z');
    local isDigit(char) = char >= '0' && char <= '9';
    local validLabelName(label) =
      local chars = std.stringChars(label);
      std.length(chars) > 0 &&
      (isLetter(chars[0]) || chars[0] == '_') &&
      std.foldl(
        function(valid, char) valid && (isLetter(char) || isDigit(char) || char == '_'),
        chars,
        true
      );
    [
      if std.type(label) != 'string'
      then error '%s must contain only Prometheus label name strings, got %s' % [groupingConfig, std.type(label)]
      else if !validLabelName(label)
      then error '%s contains an invalid Prometheus label name: %s' % [groupingConfig, label]
      else label
      for label in labels
    ],

  rejectGroupingLabels(labels, rejectedLabels, context, groupingConfig):
    local validatedLabels = self.validateGroupingLabels(labels, groupingConfig);
    local conflicts = std.foldl(
      function(conflicts, label)
        if std.member(rejectedLabels, label) && !std.member(conflicts, label)
        then conflicts + [label]
        else conflicts,
      validatedLabels,
      []
    );
    if std.length(conflicts) > 0
    then error '%s contains labels that cannot be preserved in %s: %s' % [groupingConfig, context, std.join(', ', conflicts)]
    else validatedLabels,

  rejectLabelsExcludedByWithout(labels, excludedLabels, context, groupingConfig='additionalGrouping.alertingRules'):
    local conflicts = std.foldl(
      function(conflicts, label)
        if std.member(excludedLabels, label) && !std.member(conflicts, label)
        then conflicts + [label]
        else conflicts,
      labels,
      []
    );
    if std.length(conflicts) > 0
    then error '%s contains labels removed by without() aggregations in %s: %s' % [groupingConfig, context, std.join(', ', conflicts)]
    else labels,

  requireAlertGroupingInRecordingRules(labels, recordingLabels, context):
    local missing = std.foldl(
      function(missing, label)
        if !std.member(recordingLabels, label) && !std.member(missing, label)
        then missing + [label]
        else missing,
      labels,
      []
    );
    if std.length(missing) > 0
    then error 'additionalGrouping.alertingRules labels used by recording-backed alerts must also be configured in additionalGrouping.recordingRules for %s: %s' % [context, std.join(', ', missing)]
    else labels,

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
    local additionalMatchingLabels = self.withoutLabels(
      config.additionalGrouping.alertingRules,
      labels.join_labels + ['alertname'] + (if std.objectHas(rule, 'labels') then std.objectFields(rule.labels) else [])
    );
    local matchingLabels =
      if std.length(additionalMatchingLabels) == 0
      then std.join(',', labels.on_labels)
      else self.groupingLabels(labels.on_labels, additionalMatchingLabels);

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
          on: matchingLabels,
          join: std.join(',', labels.join_labels),
          metric: labels.metric,
        },
      },

  // if showMultiCluster is true in config, return the string, otherwise return an empty string
  ifShowMultiCluster(config, string)::
    if config.showMultiCluster then string else '',
}
