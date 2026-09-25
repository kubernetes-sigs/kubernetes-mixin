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
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/prometheus/common/model"
	"github.com/prometheus/prometheus/model/rulefmt"
	"github.com/prometheus/prometheus/promql/parser"
)

type stringList []string

func (values *stringList) String() string {
	return strings.Join(*values, ",")
}

func (values *stringList) Set(value string) error {
	*values = append(*values, value)
	return nil
}

var grafanaDuration = regexp.MustCompile(`\$\{?(?:__)?(?:interval|rate_interval|resolution)\}?`)

func main() {
	var ruleFiles stringList
	var dashboardsDir string
	var outputFile string

	flag.Var(&ruleFiles, "rules", "rule file (repeatable)")
	flag.StringVar(&dashboardsDir, "dashboards", "", "dashboard directory")
	flag.StringVar(&outputFile, "output", "metrics.txt", "output path")
	flag.Parse()

	if len(ruleFiles) == 0 || dashboardsDir == "" {
		flag.Usage()
		os.Exit(2)
	}

	metrics := map[string]struct{}{}
	recordedMetrics := map[string]struct{}{}
	for _, ruleFile := range ruleFiles {
		if err := collectRuleMetrics(ruleFile, metrics, recordedMetrics); err != nil {
			fatal(err)
		}
	}
	if err := collectDashboardMetrics(dashboardsDir, metrics); err != nil {
		fatal(err)
	}
	for metric := range recordedMetrics {
		delete(metrics, metric)
	}
	if err := writeMetrics(outputFile, metrics); err != nil {
		fatal(err)
	}
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}

func collectRuleMetrics(path string, metrics, recordedMetrics map[string]struct{}) error {
	promParser := parser.NewParser(parser.Options{})
	groups, errs := rulefmt.ParseFile(path, false, model.UTF8Validation, promParser, nil)
	if len(errs) > 0 {
		return errors.Join(errs...)
	}

	for _, group := range groups.Groups {
		for _, rule := range group.Rules {
			if rule.Record != "" {
				recordedMetrics[rule.Record] = struct{}{}
			}
			if err := collectExpressionMetrics(rule.Expr, metrics); err != nil {
				return fmt.Errorf("%s: %w", path, err)
			}
		}
	}
	return nil
}

func collectDashboardMetrics(dir string, metrics map[string]struct{}) error {
	return filepath.WalkDir(dir, func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.IsDir() || filepath.Ext(path) != ".json" {
			return nil
		}

		content, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var dashboard any
		if err := json.Unmarshal(content, &dashboard); err != nil {
			return fmt.Errorf("%s: %w", path, err)
		}
		return walkDashboard(path, dashboard, metrics)
	})
}

func walkDashboard(path string, value any, metrics map[string]struct{}) error {
	switch value := value.(type) {
	case []any:
		for _, child := range value {
			if err := walkDashboard(path, child, metrics); err != nil {
				return err
			}
		}
	case map[string]any:
		for key, child := range value {
			if query, ok := child.(string); ok {
				switch key {
				case "expr":
					if err := collectExpressionMetrics(query, metrics); err != nil {
						return fmt.Errorf("%s: %w", path, err)
					}
				case "query":
					if expression, ok := unwrapTemplateQuery(query); ok {
						if err := collectExpressionMetrics(expression, metrics); err != nil {
							return fmt.Errorf("%s: %w", path, err)
						}
					}
				}
			}
			if err := walkDashboard(path, child, metrics); err != nil {
				return err
			}
		}
	}
	return nil
}

func unwrapTemplateQuery(query string) (string, bool) {
	query = strings.TrimSpace(query)
	for _, wrapper := range []string{"label_values", "query_result"} {
		prefix := wrapper + "("
		if !strings.HasPrefix(query, prefix) || !strings.HasSuffix(query, ")") {
			continue
		}
		inner := strings.TrimSpace(query[len(prefix) : len(query)-1])
		if wrapper == "label_values" {
			if comma := lastTopLevelComma(inner); comma >= 0 {
				inner = strings.TrimSpace(inner[:comma])
			}
		}
		return inner, inner != ""
	}
	return "", false
}

func lastTopLevelComma(value string) int {
	depth := 0
	quoted := false
	escaped := false
	last := -1
	for index, char := range value {
		if escaped {
			escaped = false
			continue
		}
		if quoted && char == '\\' {
			escaped = true
			continue
		}
		if char == '"' {
			quoted = !quoted
			continue
		}
		if quoted {
			continue
		}
		switch char {
		case '(', '{', '[':
			depth++
		case ')', '}', ']':
			depth--
		case ',':
			if depth == 0 {
				last = index
			}
		}
	}
	return last
}

func collectExpressionMetrics(expression string, metrics map[string]struct{}) error {
	expression = grafanaDuration.ReplaceAllString(expression, "5m")
	promParser := parser.NewParser(parser.Options{})
	expr, err := promParser.ParseExpr(expression)
	if err != nil {
		return fmt.Errorf("parse PromQL %q: %w", expression, err)
	}
	parser.Inspect(expr, func(node parser.Node, _ []parser.Node) error {
		selector, ok := node.(*parser.VectorSelector)
		if ok && selector.Name != "" {
			metrics[selector.Name] = struct{}{}
		}
		return nil
	})
	return nil
}

func writeMetrics(path string, metrics map[string]struct{}) error {
	names := make([]string, 0, len(metrics))
	for metric := range metrics {
		names = append(names, metric)
	}
	sort.Strings(names)
	return os.WriteFile(path, []byte(strings.Join(names, "\n")+"\n"), 0o644)
}
