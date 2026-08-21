SHELL := /usr/bin/env bash

# Phase 2 entrypoint — run from phase2/ (devbox shell).
#
# Usage:
#   make check
#   make check SKIP_TF_APPLY=1 SKIP_ANSIBLE=1
#   make cluster-infra-plan
#   make images-config-build RUN_PACKER_BUILD=1
#
# Flags export to setup-images.sh, setup-cluster.sh, and phase2-check.sh.

.PHONY: help check \
	images-infra-plan images-infra-deploy images-infra-destroy images-config-build \
	cluster-infra-plan cluster-infra-validate cluster-infra-deploy cluster-infra-destroy \
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

# --- Validation ladder skips (phase2-check.sh) ---
export SKIP_CLUSTER_TF ?=
export SKIP_TF_PLAN ?=
export SKIP_AMI ?=
export SKIP_AMI_PLAN ?=
export SKIP_AMI_ARTIFACT ?=
export SKIP_AMI_BUILDING ?=
export SKIP_AMI_INFRA_DEPLOY ?=
export SKIP_AMI_ANSIBLE_SYNTAX ?=
export SKIP_AMI_ANSIBLE_LINT ?=
export SKIP_TF_APPLY ?=
export SKIP_ANSIBLE ?=
export SKIP_SMOKE ?=
export SKIP_EICE_SSH ?=

# --- Cluster health polling (phase2-check.sh gates 6–7) ---
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
	@echo "  check                    full validation ladder (phase2-check.sh)"
	@echo "  images-infra-plan        AMI builder: fmt, validate, trivy, plan"
	@echo "  images-infra-deploy      AMI builder: plan + apply (builder VPC/subnet)"
	@echo "  images-config-build      AMI builder: deploy + packer build"
	@echo "  images-infra-destroy     tear down AMI builder infra"
	@echo "  cluster-infra-plan       cluster live: fmt, validate, trivy, plan"
	@echo "  cluster-infra-validate   cluster live: fmt, validate, trivy (no plan)"
	@echo "  cluster-infra-deploy     cluster live: plan + apply"
	@echo "  cluster-infra-destroy    tear down cluster infra"
	@echo "  cluster-ssh              interactive SSH to k8s node via EICE"
	@echo ""
	@echo "Common flags (append to any target):"
	@echo "  SKIP_CLUSTER_TF=1        skip cluster TF gates in check"
	@echo "  SKIP_TF_PLAN=1           cluster validate only (no terraform plan)"
	@echo "  SKIP_AMI=1               skip all AMI gates in check"
	@echo "  SKIP_AMI_PLAN=1          skip AMI infra deploy (gate 3a)"
	@echo "  SKIP_AMI_ARTIFACT=1      skip AMI presence check (gate 3b)"
	@echo "  SKIP_AMI_BUILDING=1      skip packer build inside images-config-build"
	@echo "  SKIP_AMI_INFRA_DEPLOY=1  AMI deploy runs plan only (no apply)"
	@echo "  SKIP_TF_APPLY=1          skip cluster apply gate"
	@echo "  SKIP_EICE_SSH=1          skip EICE SSH gate (5)"
	@echo "  SKIP_ANSIBLE=1           skip gates 6–8; exit after gate 5"
	@echo "  SKIP_SMOKE=1             skip gate 8 only (run gates 6–7)"
	@echo "  RUN_PACKER_BUILD=1       build AMI in check if missing (gate 3b)"
	@echo "  RUN_CLUSTER_APPLY=1      apply cluster in check (gate 4)"
	@echo "  SKIP_TRIVY=1             skip trivy in setup-*.sh"
	@echo "  SSH_PUBLIC_KEY_PATH=...  EC2 key pair public key (default: ~/.ssh/id_rsa_k8s_homelab.pub)"
	@echo "  SSH_PRIVATE_KEY_PATH=... SSH key for EICE (default: ~/.ssh/id_rsa_k8s_homelab)"
	@echo "  CLUSTER_BOOTSTRAP_TIMEOUT=900   gate 6 poll timeout (seconds)"
	@echo "  CLUSTER_HEALTH_TIMEOUT=900      gate 7 poll timeout (seconds)"
	@echo ""
	@echo "Examples:"
	@echo "  make check SKIP_TF_APPLY=1 SKIP_ANSIBLE=1"
	@echo "  make images-config-build"
	@echo "  make cluster-infra-plan"
	@echo "  make cluster-ssh"

check:
	./scripts/phase2-check.sh

images-infra-plan:
	./images/setup-images.sh plan

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

cluster-infra-deploy:
	./cluster/setup-cluster.sh deploy

cluster-infra-destroy:
	./cluster/setup-cluster.sh destroy

cluster-ssh:
	./scripts/cluster-ssh.sh
