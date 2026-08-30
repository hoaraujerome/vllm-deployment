SHELL := /usr/bin/env bash

# Phase 3 entrypoint — run from phase3/ (devbox shell).
#
# Usage:
#   make check-gates            # list gates + skip flags
#   make check                  # full ladder
#   make check-toolchain        # gate 1 only
#   make check-provisioning     # gates 1–3 (apply skipped unless RUN_PROVISIONING_APPLY=1)
#   make check-vpn              # gates 1, 4–6 (VPN path — WireGuard connected)
#   make check-full             # all gates + RUN_PROVISIONING_APPLY=1
#   make pre-commit             # local hygiene before git commit (not in ladder)
#
# Flags export to phase3-check.sh.

.PHONY: help check check-gates check-toolchain check-provisioning check-vpn check-full pre-commit

# --- AWS / Terraform defaults ---
export AWS_PROFILE ?= k8s_homelab
export AWS_REGION ?= ca-central-1
export KUBECONFIG ?= $(HOME)/.kube/vllm-phase2.conf
export WG_INTERFACE ?= utun3

# --- Gate skips (phase3-check.sh) — see: make check-gates ---
export SKIP_GATE_DEVBOX ?=
export SKIP_GATE_PROVISIONING_BLOCK ?=
export SKIP_GATE_INFRA_PLAN ?=
export SKIP_GATE_INFRA_APPLY ?=
export SKIP_GATE_RUNTIME_BLOCK ?=
export SKIP_GATE_VPN ?=
export SKIP_GATE_CLUSTER ?=
export SKIP_GATE_EICE_FREE ?=

# --- Opt-in actions ---
export RUN_PROVISIONING_APPLY ?=

help:
	@echo "Phase 3 Makefile — primary entrypoint"
	@echo ""
	@echo "Targets:"
	@echo "  check-gates              list gates 1–6 and SKIP_GATE_* flags"
	@echo "  check                    full ladder"
	@echo "  check-toolchain          gate 1 only (devbox)"
	@echo "  check-provisioning       gates 1–3 (provisioning block)"
	@echo "  check-vpn                gates 1, 4–6 (runtime — WireGuard connected)"
	@echo "  check-full               all gates + RUN_PROVISIONING_APPLY=1"
	@echo "  pre-commit               local hygiene before git commit (not in ladder)"
	@echo ""
	@echo "Presets:"
	@echo "  make check-toolchain"
	@echo "  make check-provisioning RUN_PROVISIONING_APPLY=1"
	@echo "  make check-vpn"
	@echo "  make check-full"
	@echo ""
	@echo "Skip any gate: make check-gates (or SKIP_GATE_PROVISIONING_BLOCK=1, etc.)"

check:
	./scripts/phase3-check.sh

check-gates:
	./scripts/phase3-check.sh --list-gates

check-toolchain:
	@$(MAKE) check \
		SKIP_GATE_PROVISIONING_BLOCK=1 \
		SKIP_GATE_RUNTIME_BLOCK=1

check-provisioning:
	@$(MAKE) check SKIP_GATE_RUNTIME_BLOCK=1

check-vpn:
	@$(MAKE) check SKIP_GATE_PROVISIONING_BLOCK=1

check-full:
	@$(MAKE) check RUN_PROVISIONING_APPLY=1

pre-commit:
	pre-commit run --all-files
