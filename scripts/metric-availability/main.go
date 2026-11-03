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
	"bufio"
	"flag"
	"fmt"
	"io"
	"os"
	"sort"
	"strings"

	"go.yaml.in/yaml/v3"
)

type definition struct {
	Name      string `yaml:"name"`
	Namespace string `yaml:"namespace"`
	Subsystem string `yaml:"subsystem"`
	Type      string `yaml:"type"`
}

func documentedNames(r io.Reader) (map[string]bool, error) {
	var definitions []definition
	decoder := yaml.NewDecoder(r)
	if err := decoder.Decode(&definitions); err != nil {
		return nil, fmt.Errorf("decode metric definitions: %w", err)
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return nil, fmt.Errorf("expected exactly one YAML document")
	}
	if len(definitions) == 0 {
		return nil, fmt.Errorf("metric definitions are empty")
	}
	names := map[string]bool{}
	for _, d := range definitions {
		if d.Name == "" || d.Type == "" {
			return nil, fmt.Errorf("each metric definition needs a name and type")
		}
		var parts []string
		for _, part := range []string{d.Namespace, d.Subsystem, d.Name} {
			if part != "" {
				parts = append(parts, part)
			}
		}
		name := strings.Join(parts, "_")
		switch strings.ToLower(d.Type) {
		case "histogram", "timingratiohistogram":
			for _, suffix := range []string{"_bucket", "_sum", "_count"} {
				names[name+suffix] = true
			}
		case "summary":
			names[name] = true
			names[name+"_sum"] = true
			names[name+"_count"] = true
		case "counter", "gauge", "custom", "untyped":
			names[name] = true
		default:
			return nil, fmt.Errorf("unsupported metric type %q for %s", d.Type, name)
		}
	}
	return names, nil
}

func report(required, documentation io.Reader, out io.Writer) error {
	names, err := documentedNames(documentation)
	if err != nil {
		return err
	}
	unique := map[string]bool{}
	scanner := bufio.NewScanner(required)
	for scanner.Scan() {
		name := strings.TrimSpace(scanner.Text())
		if name != "" && !strings.HasPrefix(name, "#") {
			unique[name] = true
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read required metrics: %w", err)
	}
	if len(unique) == 0 {
		return fmt.Errorf("required metrics are empty")
	}
	var sorted []string
	for name := range unique {
		sorted = append(sorted, name)
	}
	sort.Strings(sorted)
	if _, err := fmt.Fprintln(out, "metric\tstatus"); err != nil {
		return err
	}
	for _, name := range sorted {
		status := "not_in_supplied_documentation"
		if names[name] {
			status = "documented"
		}
		if _, err := fmt.Fprintf(out, "%s\t%s\n", name, status); err != nil {
			return err
		}
	}
	return nil
}

func run(args []string, out, stderr io.Writer) error {
	flags := flag.NewFlagSet("metric-availability", flag.ContinueOnError)
	flags.SetOutput(stderr)
	requiredPath := flags.String("required", "../metrics.txt", "required metric names, one per line")
	documentationPath := flags.String("documentation", "", "Kubernetes documentation-list.yaml from a pinned tag or commit")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *documentationPath == "" || flags.NArg() != 0 {
		return fmt.Errorf("provide -documentation and no positional arguments")
	}
	required, err := os.Open(*requiredPath)
	if err != nil {
		return err
	}
	defer required.Close()
	documentation, err := os.Open(*documentationPath)
	if err != nil {
		return err
	}
	defer documentation.Close()
	return report(required, documentation, out)
}

func main() {
	if err := run(os.Args[1:], os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
