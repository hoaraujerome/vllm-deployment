SHELL := /usr/bin/env bash

# Phase 2 entrypoint — run from phase2/ (devbox shell).
#
# Usage:
#   make check-gates            # list gates + skip flags
#   make check-cluster          # daily — gates 1, 9–12
#   make check-ami              # AMI factory — gates 1–6
#   make check-full             # greenfield — all gates + build + apply
#   make pre-commit             # local hygiene before git commit (not in ladder)
#
# Flags export to setup-images.sh, setup-cluster.sh, and phase2-check.sh.

.PHONY: help check check-gates check-cluster check-ami check-full pre-commit \
	images-infra-plan images-infra-apply images-infra-deploy images-infra-destroy images-config-build \
	cluster-infra-plan cluster-infra-validate cluster-infra-apply cluster-infra-deploy cluster-infra-destroy \
	cluster-ssh

# --- AWS / Terraform defaults ---
export AWS_PROFILE ?= k8s_homelab
export AWS_REGION ?= ca-central-1
export AMI_NAME_PREFIX ?= vllm-phase2-kubeadm
export SSH_PUBLIC_KEY_PATH ?= $(HOME)/.ssh/id_rsa_k8s_homelab.pub
export SSH_PRIVATE_KEY_PATH ?= $(HOME)/.ssh/id_rsa_k8s_homelab
export TF_VAR_ssh_public_key_path ?= $(SSH_PUBLIC_KEY_PATH)
export TF_VAR_ami_name_prefix ?= $(AMI_NAME_PREFIX)

# --- Orchestrator skips (passed through to setup-*.sh) ---
export SKIP_TRIVY ?=
export SKIP_AMI_INFRA_DEPLOY ?=
export SKIP_AMI_BUILDING ?=

# --- Gate skips (phase2-check.sh) — see: make check-gates ---
export SKIP_GATE_DEVBOX ?=
export SKIP_GATE_AMI_BLOCK ?=
export SKIP_GATE_AMI_ANSIBLE_SYNTAX ?=
export SKIP_GATE_AMI_ANSIBLE_LINT ?=
export SKIP_GATE_AMI_INFRA_PLAN ?=
export SKIP_GATE_AMI_INFRA_APPLY ?=
export SKIP_GATE_AMI_ARTIFACT ?=
export SKIP_GATE_CLUSTER_BLOCK ?=
export SKIP_GATE_CLUSTER_INFRA_PLAN ?=
export SKIP_GATE_CLUSTER_INFRA_APPLY ?=
export SKIP_GATE_SSH ?=
export SKIP_GATE_RUNTIME_BLOCK ?=
export SKIP_GATE_BOOTSTRAP ?=
export SKIP_GATE_NODE_READY ?=
export SKIP_GATE_SMOKE ?=

# --- Cluster health polling (gates 10–12) ---
export CLUSTER_BOOTSTRAP_TIMEOUT ?= 900
export CLUSTER_BOOTSTRAP_INTERVAL ?= 20
export CLUSTER_HEALTH_TIMEOUT ?= 900
export CLUSTER_HEALTH_INTERVAL ?= 20
export CLUSTER_SMOKE_TIMEOUT ?= 90
export CLUSTER_SMOKE_INTERVAL ?= 5

# --- Opt-in actions ---
export RUN_PACKER_BUILD ?=
export RUN_CLUSTER_APPLY ?=

help:
	@echo "Phase 2 Makefile — primary entrypoint"
	@echo ""
	@echo "Targets:"
	@echo "  check-gates              list gates 1–12 and SKIP_GATE_* flags"
	@echo "  check                    full ladder (prefer presets below)"
	@echo "  check-cluster            daily — gates 1, 9–12"
	@echo "  check-ami                AMI factory — gates 1–6"
	@echo "  check-full               greenfield — all gates + build + apply"
	@echo "  images-infra-plan        AMI builder: fmt, validate, trivy, plan"
	@echo "  images-infra-apply       AMI builder: terraform apply only"
	@echo "  images-infra-deploy      AMI builder: plan + apply"
	@echo "  images-config-build      AMI builder: deploy + packer (or packer only if SKIP_AMI_INFRA_DEPLOY=1)"
	@echo "  cluster-infra-plan       cluster live: fmt, validate, trivy, plan"
	@echo "  cluster-infra-apply      cluster live: terraform apply only"
	@echo "  cluster-infra-deploy     cluster live: plan + apply"
	@echo "  cluster-ssh              interactive SSH to k8s node via EICE"
	@echo "  pre-commit               local hygiene before git commit (not in check ladder)"
	@echo ""
	@echo "Presets:"
	@echo "  make check-cluster"
	@echo "  make check-ami RUN_PACKER_BUILD=1"
	@echo "  make check-full"
	@echo ""
	@echo "Skip any gate: make check-gates (or SKIP_GATE_AMI_BLOCK=1, etc.)"

check:
	./scripts/phase2-check.sh

check-gates:
	./scripts/phase2-check.sh --list-gates

check-cluster:
	@$(MAKE) check \
		SKIP_GATE_AMI_BLOCK=1 \
		SKIP_GATE_CLUSTER_BLOCK=1

check-ami:
	@$(MAKE) check \
		SKIP_GATE_CLUSTER_BLOCK=1 \
		SKIP_GATE_SSH=1 \
		SKIP_GATE_RUNTIME_BLOCK=1

check-full:
	@$(MAKE) check RUN_PACKER_BUILD=1 RUN_CLUSTER_APPLY=1

pre-commit:
	pre-commit run --all-files

images-infra-plan:
	./images/setup-images.sh plan

images-infra-apply:
	./images/setup-images.sh apply

images-infra-deploy:
	./images/setup-images.sh deploy

images-infra-destroy:
	./images/setup-images.sh destroy

images-config-build:
	./images/setup-images.sh build

cluster-infra-plan:
	./cluster/setup-cluster.sh plan

cluster-infra-validate:
	./cluster/setup-cluster.sh validate

cluster-infra-apply:
	./cluster/setup-cluster.sh apply

cluster-infra-deploy:
	./cluster/setup-cluster.sh deploy

cluster-infra-destroy:
	./cluster/setup-cluster.sh destroy

cluster-ssh:
	./scripts/cluster-ssh.sh
