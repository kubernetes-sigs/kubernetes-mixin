# Copyright kubernetes-mixin Authors
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BIN_DIR ?= $(shell pwd)/tmp/bin

JSONNET_VENDOR=vendor
GRAFANA_DASHBOARD_LINTER_VERSION=v0.1.0
GRAFANA_DASHBOARD_LINTER_BIN=$(BIN_DIR)/dashboard-linter
JB_BIN=$(BIN_DIR)/jb
JSONNET_BIN=$(BIN_DIR)/jsonnet
JSONNETLINT_BIN=$(BIN_DIR)/jsonnet-lint
JSONNETFMT_BIN=$(BIN_DIR)/jsonnetfmt
MD_FILES = $(shell find . \( -type d -name '.vale' -o -type d -name 'vendor' \) -prune -o -type f -name "*.md" -print)
MARKDOWNFMT_BIN=$(BIN_DIR)/markdownfmt
VALE_BIN=$(BIN_DIR)/vale
PROMTOOL_BIN=$(BIN_DIR)/promtool
PINT_BIN=$(BIN_DIR)/pint
TOOLING=$(JB_BIN) $(JSONNETLINT_BIN) $(JSONNET_BIN) $(JSONNETFMT_BIN) $(PROMTOOL_BIN) $(MARKDOWNFMT_BIN) $(VALE_BIN) $(PINT_BIN)
NPROC ?= $(shell nproc 2>/dev/null || sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
JSONNETFMT_ARGS=-n 2 --max-blank-lines 2 --string-style s --comment-style s
SRC_DIR ?=dashboards
OUT_DIR ?=dashboards_out

.PHONY: all
all: fmt generate lint test

.PHONY: dev
dev: generate lint
	@cd scripts && ./lgtm.sh && \
	echo '' && \
	echo '╔═══════════════════════════════════════════════════════════════╗' && \
	echo '║             🚀 Development Environment Ready! 🚀              ║' && \
	echo '║                                                               ║' && \
	echo '║   Run `make dev-port-forward`                                 ║' && \
	echo '║   Grafana will be available at http://localhost:3000          ║' && \
	echo '║                                                               ║' && \
	echo '║   Data will be available in a few minutes.                    ║' && \
	echo '║                                                               ║' && \
	echo '║   Dashboards will refresh every 10s, run `make generate`      ║' && \
	echo '║   and refresh your browser to see the changes.                ║' && \
	echo '║                                                               ║' && \
	echo '║   Alert and recording rules require `make dev-reload`.        ║' && \
	echo '║                                                               ║' && \
	echo '╚═══════════════════════════════════════════════════════════════╝'

.PHONY: dev-port-forward
dev-port-forward:
	kubectl --context kind-kubernetes-mixin wait --for=condition=Ready pods -l app=lgtm --timeout=300s
	kubectl --context kind-kubernetes-mixin port-forward service/lgtm 3000:3000 4317:4317 4318:4318 9090:9090

dev-reload: clean-dashboards clean-alerts clean-rules generate lint
	@cp -v prometheus_alerts.yaml scripts/provisioning/prometheus/ && \
	cp -v prometheus_rules.yaml scripts/provisioning/prometheus/ && \
	kubectl --context kind-kubernetes-mixin apply -f scripts/lgtm.yaml && \
	kubectl --context kind-kubernetes-mixin rollout restart deployment/lgtm && \
	echo '╔═══════════════════════════════════════════════════════════════╗' && \
	echo '║                                                               ║' && \
	echo '║           🔄 Reloading Alert and Recording Rules...           ║' && \
	echo '║                                                               ║' && \
	echo '╚═══════════════════════════════════════════════════════════════╝' && \
	kubectl --context kind-kubernetes-mixin rollout status deployment/lgtm

.PHONY: dev-down
dev-down:
	kind delete cluster --name kubernetes-mixin

clean-alerts:
	rm -f prometheus_alerts.yaml

clean-rules:
	rm -f prometheus_rules.yaml

clean-dashboards:
	rm -f $(OUT_DIR)/*.json*
	rm -f $(OUT_DIR)/.dashboards-generated

# Find all libsonnet files recursively in the dashboards directory
DASHBOARD_SOURCES = $(shell find $(SRC_DIR) -name '*.libsonnet' 2>/dev/null)

.PHONY: generate
generate: prometheus_alerts.yaml prometheus_rules.yaml $(OUT_DIR)/.dashboards-generated

$(JSONNET_VENDOR): $(JB_BIN) jsonnetfile.json
	$(JB_BIN) install

.PHONY: fmt
fmt: jsonnet-fmt markdownfmt

.PHONY: jsonnet-fmt
jsonnet-fmt: $(JSONNETFMT_BIN)
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -P $(NPROC) -- $(JSONNETFMT_BIN) $(JSONNETFMT_ARGS) -i

.PHONY: markdownfmt
markdownfmt: $(MARKDOWNFMT_BIN)
	@for file in $(MD_FILES); do $(MARKDOWNFMT_BIN) -w -gofmt $$file; done

prometheus_alerts.yaml: $(JSONNET_BIN) mixin.libsonnet lib/alerts.jsonnet alerts/*.libsonnet
	@$(JSONNET_BIN) -J vendor -S lib/alerts.jsonnet > $@

prometheus_rules.yaml: $(JSONNET_BIN) mixin.libsonnet lib/rules.jsonnet rules/*.libsonnet
	@$(JSONNET_BIN) -J vendor -S lib/rules.jsonnet > $@

$(OUT_DIR)/.dashboards-generated: $(JSONNET_BIN) $(JSONNET_VENDOR) mixin.libsonnet lib/dashboards.jsonnet $(DASHBOARD_SOURCES)
	@mkdir -p $(OUT_DIR)
	@$(JSONNET_BIN) -J vendor -m $(OUT_DIR) lib/dashboards.jsonnet
	@touch $@

.PHONY: lint
lint: jsonnet-lint alerts-lint dashboards-lint vale pint-lint

.PHONY: jsonnet-lint
jsonnet-lint: $(JSONNETLINT_BIN) $(JSONNET_VENDOR)
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -P $(NPROC) -- $(JSONNETLINT_BIN) -J vendor

.PHONY: alerts-lint
alerts-lint: $(PROMTOOL_BIN) prometheus_alerts.yaml prometheus_rules.yaml
	@$(PROMTOOL_BIN) check rules prometheus_rules.yaml
	@$(PROMTOOL_BIN) check rules prometheus_alerts.yaml

$(OUT_DIR)/.lint: $(OUT_DIR)/.dashboards-generated
	@cp .lint $@

.PHONY: dashboards-lint
dashboards-lint: $(GRAFANA_DASHBOARD_LINTER_BIN) $(OUT_DIR)/.lint
	# Replace $$interval:$$resolution var with $$__rate_interval to make dashboard-linter happy.
	@sed -i -e 's/$$interval:$$resolution/$$__rate_interval/g' $(OUT_DIR)/*.json
	@find $(OUT_DIR) -name '*.json' -print0 | xargs -n 1 -P $(NPROC) -0 $(GRAFANA_DASHBOARD_LINTER_BIN) lint --strict

.PHONY: vale
vale: $(VALE_BIN)
	@mkdir -p .vale/styles && \
		$(VALE_BIN) sync && \
		$(VALE_BIN) $(MD_FILES)

.PHONY: pint-lint
pint-lint: prometheus_alerts.yaml prometheus_rules.yaml $(PINT_BIN)
	@# Pint will not exit with a non-zero status code if there are linting issues.
	@output=$$($(PINT_BIN) -n -o -l WARN lint prometheus_alerts.yaml prometheus_rules.yaml 2>&1); \
	if [ -n "$$output" ]; then \
		echo "\n$$output"; \
		exit 1; \
	fi

.PHONY: clean
clean:
	# Remove all files and directories ignored by git.
	git clean -Xfd .

.PHONY: config-test
config-test: $(JSONNET_BIN) $(JSONNET_VENDOR)
	@$(JSONNET_BIN) -J vendor tests/config-test.jsonnet > /dev/null

.PHONY: test
test: $(PROMTOOL_BIN) config-test prometheus_alerts.yaml prometheus_rules.yaml
	@$(PROMTOOL_BIN) test rules tests/*.yaml

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

.PHONY: build-tools
build-tools: $(BIN_DIR)
	@echo Installing tools from scripts/tools.go
	@cd scripts && go list -e -mod=mod -tags tools -f '{{ range .Imports }}{{ printf "%s\n" .}}{{end}}' ./ | xargs -t -P $(NPROC) -I % go build -mod=mod -o $(BIN_DIR) %

$(TOOLING): $(BIN_DIR)
	@$(MAKE) build-tools

# dashboard-linter is distributed as a prebuilt binary; building from source is
# unsupported upstream because its go.mod uses a `replace` directive.
DASHBOARD_LINTER_OS = $(shell uname -s | tr '[:upper:]' '[:lower:]')
DASHBOARD_LINTER_ARCH = $(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
DASHBOARD_LINTER_ARCHIVE = dashboard-linter_$(GRAFANA_DASHBOARD_LINTER_VERSION:v%=%)_$(DASHBOARD_LINTER_OS)_$(DASHBOARD_LINTER_ARCH).tar.gz
DASHBOARD_LINTER_URL = https://github.com/grafana/dashboard-linter/releases/download/$(GRAFANA_DASHBOARD_LINTER_VERSION)/$(DASHBOARD_LINTER_ARCHIVE)

$(GRAFANA_DASHBOARD_LINTER_BIN): | $(BIN_DIR)
	@echo "Downloading dashboard-linter $(GRAFANA_DASHBOARD_LINTER_VERSION) ($(DASHBOARD_LINTER_OS)/$(DASHBOARD_LINTER_ARCH))"
	@tmp=$$(mktemp -d) && \
		curl -sSfL "$(DASHBOARD_LINTER_URL)" -o "$$tmp/$(DASHBOARD_LINTER_ARCHIVE)" && \
		curl -sSfL "https://github.com/grafana/dashboard-linter/releases/download/$(GRAFANA_DASHBOARD_LINTER_VERSION)/checksums.txt" -o "$$tmp/checksums.txt" && \
		(cd "$$tmp" && grep "  $(DASHBOARD_LINTER_ARCHIVE)$$" checksums.txt | shasum -a 256 -c -) && \
		tar -xzf "$$tmp/$(DASHBOARD_LINTER_ARCHIVE)" -C "$(BIN_DIR)" dashboard-linter && \
		rm -rf "$$tmp"

########################################
# "check-with-upstream" workflow checks.
########################################

check-selectors-ksm:
	@./scripts/check-selectors-ksm.sh
