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
  // Volume Space Usage
  volumeSpaceUsageUsed(config):: |||
    (
      sum without(instance, node) (topk(1, (kubelet_volume_stats_capacity_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))
      -
      sum without(instance, node) (topk(1, (kubelet_volume_stats_available_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))
    )
  ||| % config,

  volumeSpaceUsageFree(config):: |||
    sum without(instance, node) (topk(1, (kubelet_volume_stats_available_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))
  ||| % config,

  // Shared volumes can have multiple reporters. Aggregate each operand by PVC
  // before arithmetic so independently selected node/instance labels cannot differ.
  volumeSpaceUsagePercent(config):: |||
    100 * (
      1 -
      max by (%(clusterLabel)s, namespace, persistentvolumeclaim) (
        kubelet_volume_stats_available_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"}
      )
      /
      max by (%(clusterLabel)s, namespace, persistentvolumeclaim) (
        kubelet_volume_stats_capacity_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"}
      )
    )
  ||| % config,

  // Volume inodes Usage
  volumeInodesUsageUsed(config)::
    'sum without(instance, node) (topk(1, (kubelet_volume_stats_inodes_used{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))' % config,

  volumeInodesUsageFree(config):: |||
    (
      sum without(instance, node) (topk(1, (kubelet_volume_stats_inodes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))
      -
      sum without(instance, node) (topk(1, (kubelet_volume_stats_inodes_used{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))
    )
  ||| % config,

  volumeInodesUsagePercent(config):: |||
    100 * (
      max by (%(clusterLabel)s, namespace, persistentvolumeclaim) (
        kubelet_volume_stats_inodes_used{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"}
      )
      /
      max by (%(clusterLabel)s, namespace, persistentvolumeclaim) (
        kubelet_volume_stats_inodes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"}
      )
    )
  ||| % config,
}
