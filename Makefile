
# borrowed from https://github.com/technosophos/helm-template

HELM_3_PLUGINS := $(shell bash -c 'eval $$(helm env); echo $$HELM_PLUGINS')
HELM_PLUGIN_DIR := $(HELM_3_PLUGINS)/helm-unittest
VERSION := $(shell sed -n -e 's/version:[ "]*\([^"]*\).*/\1/p' plugin.yaml)
DIST := ./_dist
LDFLAGS := "-X main.version=${VERSION} -extldflags '-static'"
DOCKER ?= "helmunittest/helm-unittest"
PROJECT_DIR := $(shell pwd)
TEST_NAMES ?=basic \
	failing-template \
	full-snapshot \
	global-double-setting \
	invalidbasic \
	nested_glob \
	with-files \
	with-helm-tests \
	with-schema \
	with-subchart \
	with-subfolder \
	with-subsubcharts

.PHONY: help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: install
install: bootstrap build
	mkdir -p $(HELM_PLUGIN_DIR)
	cp untt $(HELM_PLUGIN_DIR)
	cp plugin.yaml $(HELM_PLUGIN_DIR)

.PHONY: install-dbg
install-dbg: bootstrap build-debug
	mkdir -p $(HELM_PLUGIN_DIR)
	cp untt-dbg $(HELM_PLUGIN_DIR)
	cp plugin-dbg.yaml $(HELM_PLUGIN_DIR)/plugin.yaml

.PHONY: hookInstall
hookInstall: bootstrap build

.PHONY: unittest
unittest: ## Run unit tests
	go test ./... -v -cover

.PHONY: build-debug
build-debug: ## Compile packages and dependencies with debug flag
	go build -o untt-dbg -gcflags "all=-N -l" ./cmd/helm-unittest

.PHONY: build
build: unittest ## Compile packages and dependencies
	go build -o untt -ldflags $(LDFLAGS) ./cmd/helm-unittest

.PHONY: dist
dist:
	mkdir -p $(DIST)
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o untt -ldflags $(LDFLAGS) ./cmd/helm-unittest
	tar -zcvf $(DIST)/helm-unittest-linux-arm64-$(VERSION).tgz untt README.md LICENSE plugin.yaml
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o untt -ldflags $(LDFLAGS) ./cmd/helm-unittest
	tar -zcvf $(DIST)/helm-unittest-linux-amd64-$(VERSION).tgz untt README.md LICENSE plugin.yaml
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o untt -ldflags $(LDFLAGS) ./cmd/helm-unittest
	tar -zcvf $(DIST)/helm-unittest-macos-amd64-$(VERSION).tgz untt README.md LICENSE plugin.yaml
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o untt -ldflags $(LDFLAGS) ./cmd/helm-unittest
	tar -zcvf $(DIST)/helm-unittest-macos-arm64-$(VERSION).tgz untt README.md LICENSE plugin.yaml
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o untt.exe -ldflags $(LDFLAGS) ./cmd/helm-unittest
	tar -zcvf $(DIST)/helm-unittest-windows-amd64-$(VERSION).tgz untt.exe README.md LICENSE plugin.yaml
	shasum -a 256 -b $(DIST)/* > $(DIST)/helm-unittest-checksum.sha
	tar -zcvf $(DIST)/helm-unittest-windows_nt-amd64-$(VERSION).tgz untt.exe README.md LICENSE plugin.yaml
	shasum -a 256 -b $(DIST)/* > $(DIST)/helm-unittest-checksum.sha

.PHONY: bootstrap
bootstrap:

.PHONY: dockerdist
dockerdist:
	./docker-build.sh

.PHONY: dockerimage
dockerimage: ## Build docker image
	docker build -t $(DOCKER):$(VERSION) .

.PHONY: test-docker
test-docker: ## Execute 'helm unittests' in container
	@for f in $(TEST_NAMES); do \
		echo "running helm unit tests in folder '$${f}'"; \
		docker run \
			-v $(PROJECT_DIR)/test/data/v3/$${f}:/apps/\
			-it --rm  $(DOCKER) -f tests/*.yaml .;\
	done
