// Copyright kubernetes-mixin Authors
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestCollectRuleMetrics(t *testing.T) {
	path := filepath.Join(t.TempDir(), "rules.yaml")
	rules := []byte(`groups:
- name: test
  rules:
  - record: recorded_metric
    expr: source_metric
  - alert: TestAlert
    expr: recorded_metric > 0
`)
	if err := os.WriteFile(path, rules, 0o644); err != nil {
		t.Fatal(err)
	}

	metrics := map[string]struct{}{}
	recordedMetrics := map[string]struct{}{}
	if err := collectRuleMetrics(path, metrics, recordedMetrics); err != nil {
		t.Fatal(err)
	}
	for metric := range recordedMetrics {
		delete(metrics, metric)
	}
	if want := map[string]struct{}{"source_metric": {}}; !reflect.DeepEqual(metrics, want) {
		t.Fatalf("metrics = %v, want %v", metrics, want)
	}
}

func TestCollectExpressionMetrics(t *testing.T) {
	metrics := map[string]struct{}{}
	expression := `sum(rate(http_requests_total[5m])) + rate(container_cpu_usage_seconds_total[$__rate_interval])`
	if err := collectExpressionMetrics(expression, metrics); err != nil {
		t.Fatal(err)
	}
	want := map[string]struct{}{
		"container_cpu_usage_seconds_total": {},
		"http_requests_total":               {},
	}
	if !reflect.DeepEqual(metrics, want) {
		t.Fatalf("metrics = %v, want %v", metrics, want)
	}
}

func TestUnwrapTemplateQuery(t *testing.T) {
	query := `label_values(metric_name{label=~"a,b"}, instance)`
	got, ok := unwrapTemplateQuery(query)
	if !ok {
		t.Fatal("query was not recognized")
	}
	if want := `metric_name{label=~"a,b"}`; got != want {
		t.Fatalf("expression = %q, want %q", got, want)
	}
}

func TestWriteMetrics(t *testing.T) {
	path := filepath.Join(t.TempDir(), "metrics.txt")
	metrics := map[string]struct{}{"metric_z": {}, "metric_a": {}}
	if err := writeMetrics(path, metrics); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if want := "metric_a\nmetric_z\n"; string(got) != want {
		t.Fatalf("output = %q, want %q", got, want)
	}
}
