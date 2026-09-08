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
  prometheusRules+:: {
    local unitSeconds = {
      ms: 0.001,
      s: 1,
      m: 60,
      h: 60 * 60,
      d: 24 * 60 * 60,
      w: 7 * 24 * 60 * 60,
      y: 365 * 24 * 60 * 60,
    },

    // Prometheus duration literals: one or more <value><unit> pairs, so 5m, 500ms, 1h30m
    // and 2w all parse. Duration expressions are out of scope, since the window is
    // appended to the record name and an expression cannot appear there.
    local windowSeconds(window) =
      local chars = std.stringChars(window);
      local last = std.length(chars) - 1;
      local consume(state, i) =
        if state.skip then
          state { skip: false }
        else
          local char = chars[i];
          if char >= '0' && char <= '9' then
            state { value: state.value + char }
          else
            local milli = char == 'm' && i < last && chars[i + 1] == 's';
            local unit = if milli then 'ms' else char;
            if !std.objectHas(unitSeconds, unit) then
              error 'unsupported duration unit %s in window %s' % [unit, window]
            else if state.value == '' then
              error 'duration unit %s without a value in window %s' % [unit, window]
            else
              {
                seconds: state.seconds + std.parseInt(state.value) * unitSeconds[unit],
                value: '',
                skip: milli,
              };
      local parsed = std.foldl(consume, std.range(0, last), { seconds: 0, value: '', skip: false });
      if window == '0' then
        0
      else if parsed.value != '' then
        error 'duration value without a unit in window %s' % window
      else
        parsed.seconds,

    local shorter(a, b) = if windowSeconds(b) < windowSeconds(a) then b else a,
    local longer(a, b) = if windowSeconds(b) > windowSeconds(a) then b else a,

    local shortWindows = std.set([w.short for w in $._config.SLOs.apiserver.windows]),
    local windows = std.set(shortWindows + [w.long for w in $._config.SLOs.apiserver.windows]),

    // The intermediate series are recorded on the shortest window in use, so that the
    // burn rate for that window stays an exact rewrite rather than an approximation.
    local baseWindow = std.foldl(shorter, windows, windows[0]),

    // Short windows decide how fast an alert reacts, so they keep reading the raw series.
    // Longer windows are averaged from the intermediate series instead: their cost is
    // dominated by the range length, and a range that long over the raw apiserver series
    // is what makes this group expensive. The averaged value trails the raw one by half
    // the base window while the request rate is changing, and matches it once the rate
    // holds steady, which is the condition the long window is there to detect.
    local longestShortWindow = std.foldl(longer, shortWindows, shortWindows[0]),
    local rawWindows = [w for w in windows if windowSeconds(w) <= windowSeconds(longestShortWindow)],
    local averagedWindows = [w for w in windows if windowSeconds(w) > windowSeconds(longestShortWindow)],

    local badRecord = 'cluster_verb:apiserver_request_sli_bad_events:rate%s' % baseWindow,
    local totalRecord = 'cluster_verb:apiserver_request_sli_events:rate%s' % baseWindow,

    // Requests that either breached the latency objective for their scope or returned 5xx.
    local badExpr(verb, window) =
      if verb == 'read' then
        |||
          (
            (
              # too slow
              sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_count{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s}[%(window)s]))
              -
              (
                (
                  sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s,scope=~"resource|",le=~"%(kubeApiserverReadResourceLatency)s"}[%(window)s]))
                  or
                  vector(0)
                )
                +
                sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s,scope="namespace",le=~"%(kubeApiserverReadNamespaceLatency)s"}[%(window)s]))
                +
                sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s,scope="cluster",le=~"%(kubeApiserverReadClusterLatency)s"}[%(window)s]))
              )
            )
            +
            # errors
            sum by (%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,code=~"5.."}[%(window)s]))
          )
        ||| % {
          clusterLabel: $._config.clusterLabel,
          window: window,
          kubeApiserverSelector: $._config.kubeApiserverSelector,
          kubeApiserverReadSelector: $._config.kubeApiserverReadSelector,
          kubeApiserverNonStreamingSelector: $._config.kubeApiserverNonStreamingSelector,
          kubeApiserverReadResourceLatency: $._config.kubeApiserverReadResourceLatency,
          kubeApiserverReadNamespaceLatency: $._config.kubeApiserverReadNamespaceLatency,
          kubeApiserverReadClusterLatency: $._config.kubeApiserverReadClusterLatency,
        }
      else
        |||
          (
            (
              # too slow
              sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_count{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,%(kubeApiserverNonStreamingSelector)s}[%(window)s]))
              -
              sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,%(kubeApiserverNonStreamingSelector)s,le=~"%(kubeApiserverWriteLatency)s"}[%(window)s]))
            )
            +
            # errors
            sum by (%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,code=~"5.."}[%(window)s]))
          )
        ||| % {
          clusterLabel: $._config.clusterLabel,
          window: window,
          kubeApiserverSelector: $._config.kubeApiserverSelector,
          kubeApiserverWriteSelector: $._config.kubeApiserverWriteSelector,
          kubeApiserverNonStreamingSelector: $._config.kubeApiserverNonStreamingSelector,
          kubeApiserverWriteLatency: $._config.kubeApiserverWriteLatency,
        },

    local totalExpr(verb, window) =
      |||
        sum by (%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s,%(verbSelector)s}[%(window)s]))
      ||| % {
        clusterLabel: $._config.clusterLabel,
        window: window,
        kubeApiserverSelector: $._config.kubeApiserverSelector,
        verbSelector: if verb == 'read' then $._config.kubeApiserverReadSelector else $._config.kubeApiserverWriteSelector,
      },

    groups+: [
      {
        name: 'kube-apiserver-burnrate.rules',
        // Without SLO windows there are no KubeAPIErrorBudgetBurn alerts for these rules
        // to feed, so record nothing rather than fail on an empty window list.
        rules: if std.length(windows) == 0 then [] else [
          {
            record: badRecord,
            expr: badExpr(verb, baseWindow),
            labels: {
              verb: verb,
            },
          }
          for verb in ['read', 'write']
        ] + [
          {
            record: totalRecord,
            expr: totalExpr(verb, baseWindow),
            labels: {
              verb: verb,
            },
          }
          for verb in ['read', 'write']
        ] + [
          // Both verbs at once: the intermediate series already carry the verb label.
          {
            record: 'apiserver_request:burnrate%s' % baseWindow,
            expr: |||
              %s
              /
              %s
            ||| % [badRecord, totalRecord],
          },
        ] + [
          {
            record: 'apiserver_request:burnrate%(window)s' % { window: window },
            expr: |||
              %(bad)s
              /
              %(total)s
            ||| % {
              bad: std.rstripChars(badExpr(verb, window), '\n'),
              total: std.rstripChars(totalExpr(verb, window), '\n'),
            },
            labels: {
              verb: verb,
            },
          }
          for window in rawWindows
          if window != baseWindow
          for verb in ['read', 'write']
        ] + [
          {
            record: 'apiserver_request:burnrate%(window)s' % { window: window },
            expr: |||
              avg_over_time(%(bad)s[%(window)s])
              /
              avg_over_time(%(total)s[%(window)s])
            ||| % {
              bad: badRecord,
              total: totalRecord,
              window: window,
            },
          }
          for window in averagedWindows
        ],
      },
    ],
  },
}
