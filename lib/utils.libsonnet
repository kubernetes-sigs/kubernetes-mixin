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

// Removes duplicates while keeping the first occurrence of each element in place.
local unique(items) = std.foldl(
  function(acc, item) if std.member(acc, item) then acc else acc + [item],
  items,
  []
);

// The configured labels of one kind, which are empty when the configuration does not define them,
// for example after overriding additionalGrouping without `+`.
local configuredGroupingLabels(config, kind) = std.get(std.get(config, 'additionalGrouping', {}), kind, []);

local groupingLabels(queryLabels, additionalLabels) =
  std.join(', ', unique(queryLabels + additionalLabels));

local withoutLabels(labels, excludedLabels) =
  [label for label in labels if !std.member(excludedLabels, label)];

// Returns the labels, or fails with the message and the conflicting labels when there are any.
local failOnConflicts(labels, conflicts, message) =
  if std.length(conflicts) > 0
  then error '%s: %s' % [message, std.join(', ', unique(conflicts))]
  else labels;

local validateGroupingLabels(labels, groupingConfig) =
  local isLetter(char) =
    (char >= 'a' && char <= 'z') ||
    (char >= 'A' && char <= 'Z');
  local isDigit(char) = char >= '0' && char <= '9';
  local validLabelName(label) =
    local chars = std.stringChars(label);
    std.length(chars) > 0 &&
    (isLetter(chars[0]) || chars[0] == '_') &&
    std.all([isLetter(char) || isDigit(char) || char == '_' for char in chars]);
  local reservedLabelName(label) =
    local chars = std.stringChars(label);
    std.length(chars) > 2 &&
    (chars[0] == '_') && (chars[1] == '_');
  [
    if std.type(label) != 'string'
    then error '%s must contain only Prometheus label name strings, got %s' % [groupingConfig, std.type(label)]
    else if !validLabelName(label)
    then error '%s contains an invalid Prometheus label name: %s' % [groupingConfig, label]
    else if reservedLabelName(label)
    then error '%s contains a reserved Prometheus label name that should not be used for grouping: %s' % [groupingConfig, label]
    else label
    for label in labels
  ];

local rejectGroupingLabels(labels, rejectedLabels, context, groupingConfig) =
  failOnConflicts(
    labels,
    [label for label in labels if std.member(rejectedLabels, label)],
    '%s contains labels that cannot be preserved in %s' % [groupingConfig, context]
  );

local rejectLabelsExcludedByWithout(labels, excludedLabels, context, groupingConfig) =
  failOnConflicts(
    labels,
    [label for label in labels if std.member(excludedLabels, label)],
    '%s contains labels removed by without() aggregations in %s' % [groupingConfig, context]
  );

local requireAlertGroupingInRecordingRules(labels, recordingLabels, context) =
  failOnConflicts(
    labels,
    [label for label in labels if !std.member(recordingLabels, label)],
    'additionalGrouping.alertingRules labels used by recording-backed alerts must also be configured in additionalGrouping.recordingRules for %s' % context
  );

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

  // Validates the configured additional grouping labels of one kind ('recordingRules' or
  // 'alertingRules') for a module. Labels are rejected when they are not valid label names,
  // when the module's without() aggregations drop them (removedByWithout), or when the
  // module's queries consume, overwrite or otherwise cannot preserve them (rejected). The
  // labels every rule of the kind reserves are rejected implicitly. Returns the validated
  // labels, a by() helper that appends them, minus any per-rule exclusions, to a list of
  // query labels, and requireRecorded() for alerts that read recording rules.
  grouping(config, kind, context, rejected=[], removedByWithout=[])::
    local name = 'additionalGrouping.' + kind;
    local reserved = if kind == 'alertingRules' then ['__name__', 'alertname', 'severity'] else ['__name__'];
    local labels = rejectGroupingLabels(
      rejectLabelsExcludedByWithout(
        validateGroupingLabels(configuredGroupingLabels(config, kind), name),
        removedByWithout,
        context,
        name
      ),
      reserved + rejected,
      context,
      name
    );
    {
      labels: labels,
      by(queryLabels, excluded=[]):: groupingLabels(queryLabels, withoutLabels(labels, excluded)),
      // Checks that the labels, minus the inherentlyRecordedLabels, which the alert does not read from
      // recording rules, are also configured for the recording rules that back the alert.
      requireRecorded(inherentlyRecordedLabels, alertContext)::
        requireAlertGroupingInRecordingRules(
          withoutLabels(labels, inherentlyRecordedLabels),
          configuredGroupingLabels(config, 'recordingRules'),
          alertContext
        ),
    },

  humanizeSeconds(s)::
    if s > 60 * 60 * 24
    then '%.1f days' % (s / 60 / 60 / 24)
    else '%.1f hours' % (s / 60 / 60),

  // Handle adding `group left` to join labels into rule by wrapping the rule in () * on(xxx) group_left(xxx) kube_xxx_labels
  // If kind of rule is not defined try to detect rule type by alert name
  // additionalLabels are the validated additionalGrouping.alertingRules of the calling module.
  // Without them, the configured list is used as is.
  wrap_rule_for_labels(rule, config, additionalLabels):
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
    local additionalMatchingLabels = withoutLabels(
      if additionalLabels == null then [] else additionalLabels,
      labels.join_labels + ['alertname'] + (if std.objectHas(rule, 'labels') then std.objectFields(rule.labels) else [])
    );
    local matchingLabels =
      if std.length(additionalMatchingLabels) == 0
      then std.join(',', labels.on_labels)
      else groupingLabels(labels.on_labels, additionalMatchingLabels);

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
