MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ENV_FILE ?= $(MAKEFILE_DIR).env
ENV_EXAMPLE ?= $(MAKEFILE_DIR).env.example

ENV_FILE_USED :=
ifneq ("$(wildcard $(ENV_FILE))","")
ENV_FILE_USED := $(ENV_FILE)
include $(ENV_FILE)
else ifneq ("$(wildcard $(ENV_EXAMPLE))","")
ENV_FILE_USED := $(ENV_EXAMPLE)
include $(ENV_EXAMPLE)
$(info Using $(ENV_EXAMPLE); copy to $(ENV_FILE) to customize)
endif

include $(MAKEFILE_DIR)versions.mk

.DEFAULT_GOAL := help

CLUSTER_NAME ?=
CLUSTER_NODE_IP ?=
CLUSTER_INSTALL_DISK ?=
CLUSTER_INSTALL_IMAGE_BASE ?=

CLUSTER_ADDITIONAL_SANS ?= $(CLUSTER_NODE_IP)
CLUSTER_CONFIG_OUTPUT_CONTROLPLANE ?= $(CLUSTER_CONFIG_OUTPUT_DIR)/controlplane.yaml
CLUSTER_CONFIG_OUTPUT_DIR ?= .
CLUSTER_CONFIG_OUTPUT_TALOSCONFIG ?= $(CLUSTER_CONFIG_OUTPUT_DIR)/talosconfig
CLUSTER_CONFIG_OUTPUT_WORKER ?= $(CLUSTER_CONFIG_OUTPUT_DIR)/worker.yaml
CLUSTER_CONFIG_WITH_DOCS ?= false
CLUSTER_CONFIG_WITH_EXAMPLES ?= false
CLUSTER_CONFIG_WITH_KUBESPAN ?= false
CLUSTER_DNS_DOMAIN ?= cluster.local
CLUSTER_VALIDATE_MODE ?= metal
CLUSTER_ENDPOINT ?= https://$(CLUSTER_NODE_IP):6443
CLUSTER_SECRETS_FILE ?= secrets.yaml
CLUSTER_INSTALL_IMAGE ?= $(CLUSTER_INSTALL_IMAGE_BASE):$(CLUSTER_TALOS_VERSION)
TALOS_NODE_ENDPOINT ?= $(CLUSTER_NODE_IP)
BACKUP_OUTPUT_DIR ?= $(MAKEFILE_DIR)backups
BACKUP_RETENTION_DAYS ?= 30

GEN_CONFIG_COMMON_FLAGS = \
	--additional-sans $(CLUSTER_ADDITIONAL_SANS) \
	--config-patch @patches/common.yaml \
	--dns-domain $(CLUSTER_DNS_DOMAIN) \
	--force \
	--install-disk $(CLUSTER_INSTALL_DISK) \
	--install-image $(CLUSTER_INSTALL_IMAGE) \
	--kubernetes-version $(CLUSTER_KUBERNETES_VERSION) \
	--talos-version $(CLUSTER_TALOS_VERSION) \
	--with-docs=$(CLUSTER_CONFIG_WITH_DOCS) \
	--with-examples=$(CLUSTER_CONFIG_WITH_EXAMPLES) \
	--with-kubespan=$(CLUSTER_CONFIG_WITH_KUBESPAN) \
	--with-secrets $(CLUSTER_SECRETS_FILE)

.PHONY: help prepare-output-dir check-tools check-env check-talosconfig \
	config config-dry-run validate install apply upgrade upgrade-k8s secrets clean backup backup-prune bootstrap-sops \
	talosctl-gen-secrets talosctl-gen-config-controlplane talosctl-gen-config-worker \
	talosctl-gen-config-talosconfig talosctl-gen-config \
	validate-configs talosctl-apply-config-dry-run talosctl-apply-config talosctl-apply-config-and-bootstrap \
	talosctl-upgrade talosctl-upgrade-k8s talosctl-etcd-backup clean-configs

help:
	@printf '%s\n' \
		'Usage: make <target>' \
		'' \
		'Use-case targets:' \
		'  config          Generate controlplane/worker/talosconfig' \
		'  config-dry-run  Dry-run apply controlplane config' \
		'  validate        Generate and validate controlplane/worker configs' \
		'  install         Apply config and bootstrap (Day0)' \
		'  apply           Apply controlplane config (Day2 changes)' \
		'  upgrade         Upgrade Talos' \
		'  upgrade-k8s     Upgrade Kubernetes' \
		'  secrets         Generate install/secrets.yaml' \
		'  backup          Create etcd snapshot + sha256 checksum' \
		'  backup-prune    Remove local snapshots older than BACKUP_RETENTION_DAYS' \
		'  bootstrap-sops  Generate age key + create/update argocd sops-age secret' \
		'  clean           Remove generated configs (not secrets)' \
		'' \
		'Low-level targets:' \
		'  talosctl-gen-secrets                Generate install/secrets.yaml' \
		'  talosctl-gen-config                 Generate controlplane/worker/talosconfig' \
		'  talosctl-apply-config-dry-run        Dry-run apply controlplane config' \
		'  talosctl-apply-config                Apply controlplane config' \
		'  talosctl-apply-config-and-bootstrap  Apply config and bootstrap' \
		'  talosctl-upgrade                     Upgrade Talos' \
		'  talosctl-upgrade-k8s                 Upgrade Kubernetes' \
		'  talosctl-etcd-backup                 Create etcd snapshot + checksum' \
		'  clean-configs                        Remove generated configs (not secrets)' \
		'' \
		'Common variables (set via ENV_FILE):' \
		'  CLUSTER_NAME, CLUSTER_NODE_IP, CLUSTER_INSTALL_DISK, CLUSTER_INSTALL_IMAGE_BASE' \
		'' \
		'Optional variables:' \
		'  CLUSTER_TALOS_VERSION, CLUSTER_KUBERNETES_VERSION' \
		'  CLUSTER_CONFIG_OUTPUT_DIR, CLUSTER_ADDITIONAL_SANS, CLUSTER_ENDPOINT' \
		'  CLUSTER_VALIDATE_MODE (metal|cloud|container)' \
		'  TALOS_NODE_ENDPOINT (Talos API node target)' \
		'  BACKUP_OUTPUT_DIR, BACKUP_RETENTION_DAYS' \
		'' \
		'Env file:' \
		'  ENV_FILE (default: install/.env)'

prepare-output-dir:
	@mkdir -p $(CLUSTER_CONFIG_OUTPUT_DIR)

check-tools:
	@command -v talosctl >/dev/null 2>&1 || { echo "talosctl not found in PATH"; exit 1; }
	@talosctl version --client >/dev/null 2>&1 || true

check-env:
	@$(if $(ENV_FILE_USED),,$(error Missing env file: create $(ENV_FILE) (see $(ENV_EXAMPLE))))
	@$(foreach var,CLUSTER_NAME CLUSTER_NODE_IP CLUSTER_INSTALL_DISK CLUSTER_INSTALL_IMAGE_BASE,\
		$(if $($(var)),,$(error Missing required variable: $(var)))\
	)

check-talosconfig:
	@test -f $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG) || { echo "Missing $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG). Generate it first with 'make config'."; exit 1; }

talosctl-gen-secrets: check-tools
	@test -f $(MAKEFILE_DIR).gitignore && grep -q '^secrets\.yaml$$' $(MAKEFILE_DIR).gitignore || { echo "install/.gitignore must include secrets.yaml"; exit 1; }
	test -f $(CLUSTER_SECRETS_FILE) || talosctl gen secrets \
		--output-file $(CLUSTER_SECRETS_FILE) \
		--talos-version $(CLUSTER_TALOS_VERSION)
	@test -f $(CLUSTER_SECRETS_FILE)
	@chmod 600 $(CLUSTER_SECRETS_FILE)

talosctl-gen-config-controlplane: check-env talosctl-gen-secrets prepare-output-dir
	talosctl gen config $(CLUSTER_NAME) $(CLUSTER_ENDPOINT) \
		$(GEN_CONFIG_COMMON_FLAGS) \
		--config-patch-control-plane @patches/controlplane.yaml \
		--output $(CLUSTER_CONFIG_OUTPUT_CONTROLPLANE) \
		--output-types controlplane

talosctl-gen-config-worker: check-env talosctl-gen-secrets prepare-output-dir
	talosctl gen config $(CLUSTER_NAME) $(CLUSTER_ENDPOINT) \
		$(GEN_CONFIG_COMMON_FLAGS) \
		--config-patch-worker @patches/worker.yaml \
		--output $(CLUSTER_CONFIG_OUTPUT_WORKER) \
		--output-types worker

talosctl-gen-config-talosconfig: check-env talosctl-gen-secrets prepare-output-dir
	talosctl gen config $(CLUSTER_NAME) $(CLUSTER_ENDPOINT) \
		$(GEN_CONFIG_COMMON_FLAGS) \
		--output $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG) \
		--output-types talosconfig && \
	talosctl --talosconfig $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG) config endpoint $(TALOS_NODE_ENDPOINT)
	talosctl --talosconfig $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG) config node $(TALOS_NODE_ENDPOINT)

talosctl-gen-config: talosctl-gen-config-controlplane talosctl-gen-config-worker talosctl-gen-config-talosconfig

validate-configs: check-tools
	talosctl validate --config $(CLUSTER_CONFIG_OUTPUT_CONTROLPLANE) --mode $(CLUSTER_VALIDATE_MODE)
	talosctl validate --config $(CLUSTER_CONFIG_OUTPUT_WORKER) --mode $(CLUSTER_VALIDATE_MODE)

validate: talosctl-gen-config validate-configs

talosctl-apply-config-dry-run: validate
	talosctl \
		--talosconfig $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG) \
		--nodes $(TALOS_NODE_ENDPOINT) apply-config --dry-run -f $(CLUSTER_CONFIG_OUTPUT_CONTROLPLANE)

talosctl-apply-config: talosctl-gen-config
	talosctl \
		--talosconfig $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG) \
		--nodes $(TALOS_NODE_ENDPOINT) apply-config -f $(CLUSTER_CONFIG_OUTPUT_CONTROLPLANE)

talosctl-apply-config-and-bootstrap: talosctl-gen-config
	talosctl -n $(TALOS_NODE_ENDPOINT) apply-config --insecure -f $(CLUSTER_CONFIG_OUTPUT_CONTROLPLANE) && \
	talosctl \
		--talosconfig $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG) \
		--nodes $(TALOS_NODE_ENDPOINT) bootstrap

talosctl-upgrade: check-tools
	talosctl \
		--talosconfig $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG) \
		--nodes $(TALOS_NODE_ENDPOINT) \
		upgrade \
		--image $(CLUSTER_INSTALL_IMAGE) \
		--preserve=true

talosctl-upgrade-k8s: check-tools
	talosctl \
		--talosconfig $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG) \
		--nodes $(TALOS_NODE_ENDPOINT) \
		upgrade-k8s \
		--to $(CLUSTER_KUBERNETES_VERSION) \
		--with-docs=$(CLUSTER_CONFIG_WITH_DOCS) \
		--with-examples=$(CLUSTER_CONFIG_WITH_EXAMPLES)

talosctl-etcd-backup: check-tools check-env check-talosconfig
	@set -euo pipefail; \
	mkdir -p $(BACKUP_OUTPUT_DIR); \
	ts=$$(date -u +%Y%m%dT%H%M%SZ); \
	backup_file="$(BACKUP_OUTPUT_DIR)/$(CLUSTER_NAME)-etcd-$${ts}.db"; \
	talosctl \
		--talosconfig $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG) \
		--nodes $(TALOS_NODE_ENDPOINT) \
		etcd snapshot "$$backup_file"; \
	if command -v sha256sum >/dev/null 2>&1; then \
		sha256sum "$$backup_file" > "$$backup_file.sha256"; \
	else \
		shasum -a 256 "$$backup_file" > "$$backup_file.sha256"; \
	fi; \
	echo "Created $$backup_file and $$backup_file.sha256"

clean-configs:
	rm -f $(CLUSTER_CONFIG_OUTPUT_CONTROLPLANE) $(CLUSTER_CONFIG_OUTPUT_WORKER) $(CLUSTER_CONFIG_OUTPUT_TALOSCONFIG)

config: validate

config-dry-run: talosctl-apply-config-dry-run

install: talosctl-apply-config-and-bootstrap

apply: talosctl-apply-config

upgrade: talosctl-upgrade

upgrade-k8s: talosctl-upgrade-k8s

secrets: talosctl-gen-secrets

clean: clean-configs

backup: talosctl-etcd-backup

backup-prune:
	@set -euo pipefail; \
	mkdir -p $(BACKUP_OUTPUT_DIR); \
	find $(BACKUP_OUTPUT_DIR) -type f \( -name '*.db' -o -name '*.sha256' \) -mtime +$(BACKUP_RETENTION_DAYS) -print -delete

bootstrap-sops:
	@K8S_CONTEXT=$${K8S_CONTEXT:-admin@sidero} $(MAKEFILE_DIR)../scripts/bootstrap-sops.sh
