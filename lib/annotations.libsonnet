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
    expr: 'sum by (pod, container) (increase(kube_pod_container_status_restarts_total{cluster="$cluster", namespace="$namespace"}[5m])) > 0',
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

  // Pass `$._config.grafanaK8s.containerRestartAnnotation` as `include` and
  // `$._config.grafanaK8s.containerRestartAnnotationEnable` as `enable`.
  withContainerRestarts(include, enable)::
    if include then
      { annotations+: { list+: [$.containerRestarts { enable: enable }] } }
    else {},
}
