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
  // Annotations to be added to dashboards.
  containerRestarts: {
    datasource: { type: 'prometheus', uid: '$datasource' },
    hide: false,
    iconColor: 'red',
    name: 'Container restarts',
    step: '60s',
    tagKeys: 'pod,container',
    textFormat: '{{pod}} / {{container}} restarted',
    titleFormat: 'Container restart',
    type: 'alert',
    useValueForTime: false,
  },

  // Builds the container-restarts expression.
  // `namespaceMatcher`: '=' or '=~' for the namespace selector; use '=~' on
  // dashboards whose namespace variable has an All option.
  // `podMatcher`: '=' or '=~' to filter by the dashboard's pod variable;
  // leave null on dashboards without a pod variable.
  // `workload`: filter by the dashboard's `$workload` variable.
  // `type`: filter by the dashboard's `$type` variable.
  // `windows`: restrict to Windows pods.
  containerRestartsExpr(config, namespaceMatcher='=', podMatcher=null, workload=false, type=false, windows=false)::
    local clusterLabel = config.clusterLabel;
    local ns = namespaceMatcher;
    local pod = if podMatcher == null then '' else ', pod' + podMatcher + '"$pod"';
    local base =
      '(sum by (namespace, pod, container) (increase(kube_pod_container_status_restarts_total{%(clusterLabel)s="$cluster", namespace%(ns)s"$namespace"%(pod)s}[5m])) > 0)' % {
        clusterLabel: clusterLabel,
        ns: ns,
        pod: pod,
      };
    local workloads =
      if workload || type then
        ('* on (%(clusterLabel)s, namespace, pod) group_left(workload, workload_type) ' +
         'namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace%(ns)s"$namespace", workload=~"%(workload)s", workload_type=~"$type"}') % {
          clusterLabel: clusterLabel,
          ns: ns,
          workload: if workload then '$workload' else '.+',
        }
      else null;
    local windowsFilter =
      if windows then
        ('and on (%(clusterLabel)s, namespace, pod) windows_pod_container_available{%(clusterLabel)s="$cluster", namespace%(ns)s"$namespace"}') % {
          clusterLabel: clusterLabel,
          ns: ns,
        }
      else null;
    std.join(' ', std.filter(function(part) part != null, [base, workloads, windowsFilter])),

  // Adds the container-restarts annotation to a dashboard, honouring the
  // `containerRestartAnnotation` and `containerRestartAnnotationEnable` config
  // options. Pass `$._config`. The remaining arguments select the expression
  // variant, see `containerRestartsExpr`.
  withContainerRestarts(config, namespaceMatcher='=', podMatcher=null, workload=false, type=false, windows=false)::
    if config.grafanaK8s.containerRestartAnnotation then
      {
        annotations+: {
          list+: [
            $.containerRestarts {
              enable: config.grafanaK8s.containerRestartAnnotationEnable,
              expr: $.containerRestartsExpr(config, namespaceMatcher=namespaceMatcher, podMatcher=podMatcher, workload=workload, type=type, windows=windows),
            },
          ],
        },
      }
    else {},
}
