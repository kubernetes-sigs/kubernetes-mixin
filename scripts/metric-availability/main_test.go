// Copyright kubernetes-mixin Authors
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bytes"
	"io"
	"strings"
	"testing"
)

func TestReport(t *testing.T) {
	documentation := `
- name: latency_seconds
  namespace: control
  subsystem: queue
  type: Histogram
- name: request_seconds
  subsystem: api
  type: Summary
- name: calls_total
  type: Counter
`
	required := "node_cpu_seconds_total\ncontrol_queue_latency_seconds_bucket\napi_request_seconds_count\napi_request_seconds\napi_request_seconds_bucket\ncalls_total\ncalls_total\n\n# comment\n"
	var out bytes.Buffer
	if err := report(strings.NewReader(required), strings.NewReader(documentation), &out); err != nil {
		t.Fatal(err)
	}
	want := "metric\tstatus\n" +
		"api_request_seconds\tdocumented\n" +
		"api_request_seconds_bucket\tnot_in_supplied_documentation\n" +
		"api_request_seconds_count\tdocumented\n" +
		"calls_total\tdocumented\n" +
		"control_queue_latency_seconds_bucket\tdocumented\n" +
		"node_cpu_seconds_total\tnot_in_supplied_documentation\n"
	if out.String() != want {
		t.Fatalf("got:\n%s\nwant:\n%s", out.String(), want)
	}
}

func TestDocumentedNames(t *testing.T) {
	names, err := documentedNames(strings.NewReader("- name: duration_seconds\n  type: Histogram\n- name: demand_seats\n  subsystem: flowcontrol\n  type: TimingRatioHistogram\n"))
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"duration_seconds_bucket", "duration_seconds_sum", "duration_seconds_count"} {
		if !names[name] {
			t.Errorf("missing %s", name)
		}
	}
	if names["duration_seconds"] {
		t.Error("histogram family name is not an exposed classic histogram series")
	}
	if !names["flowcontrol_demand_seats_bucket"] || !names["flowcontrol_demand_seats_sum"] || !names["flowcontrol_demand_seats_count"] {
		t.Error("timing ratio histogram series are missing")
	}
}

func TestInvalidInputs(t *testing.T) {
	for _, doc := range []string{"", "[]", "- name: [", "- help: no name", "- name: no_type", "- name: metric\n  type: Unknown", "- name: metric\n  type: Gauge\n---\n[]"} {
		if err := report(strings.NewReader("metric"), strings.NewReader(doc), io.Discard); err == nil {
			t.Errorf("expected error for documentation %q", doc)
		}
	}
	if err := report(strings.NewReader("\n# empty"), strings.NewReader("- name: metric\n  type: Gauge"), io.Discard); err == nil {
		t.Error("expected error for empty required metrics")
	}
	if err := run(nil, io.Discard, io.Discard); err == nil {
		t.Error("expected missing documentation argument error")
	}
	if err := run([]string{"-documentation", "does-not-exist", "-required", "does-not-exist"}, io.Discard, io.Discard); err == nil {
		t.Error("expected file error")
	}
}
