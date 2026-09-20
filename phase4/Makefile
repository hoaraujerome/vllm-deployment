SHELL := /usr/bin/env bash

# Phase 4 entrypoint — run from phase4/ (WireGuard + kubectl from laptop).
#
# Usage:
#   make check-gates            # list gates + skip flags
#   make check                  # full ladder
#   make check-chart            # gate 1 only (helm lint)
#   make check-deploy           # gates 1–5 (install + verify vLLM)
#
# Flags export to phase4-check.sh.

.PHONY: help check check-gates check-chart check-deploy helm-install helm-uninstall

export KUBECONFIG ?= $(HOME)/.kube/vllm-phase2.conf
export KUBE_CONTEXT ?=
export RELEASE ?= vllm
export NAMESPACE ?= vllm
export DEPLOY_TIMEOUT ?= 180

export SKIP_GATE_STATIC ?=
export SKIP_GATE_DEPLOY_BLOCK ?=
export SKIP_GATE_ARTIFACT ?=
export SKIP_GATE_DEPLOY ?=
export SKIP_GATE_FUNCTIONAL ?=
export SKIP_GATE_RESOURCE ?=

help:
	@echo "Phase 4 Makefile — primary entrypoint"
	@echo ""
	@echo "Targets:"
	@echo "  check-gates              list gates 1–5 and SKIP_GATE_* flags"
	@echo "  check                    full ladder (same as check-deploy)"
	@echo "  check-chart              gate 1 only (helm lint)"
	@echo "  check-deploy             gates 1–5 — install vLLM and verify"
	@echo "  helm-install             helm upgrade --install only (no gates)"
	@echo "  helm-uninstall           remove release from cluster"
	@echo ""
	@echo "Presets:"
	@echo "  make check-chart"
	@echo "  make check-deploy"
	@echo ""
	@echo "Prerequisite: WireGuard up, KUBECONFIG valid (phase3 make fetch-kubeconfig)"

check:
	./scripts/phase4-check.sh

check-gates:
	./scripts/phase4-check.sh --list-gates

check-chart:
	@$(MAKE) check \
		SKIP_GATE_DEPLOY_BLOCK=1

check-deploy:
	@$(MAKE) check

helm-install:
	helm upgrade --install $(RELEASE) helm/vllm \
		--kubeconfig "$(KUBECONFIG)" \
		$(if $(KUBE_CONTEXT),--kube-context $(KUBE_CONTEXT),) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--atomic \
		--wait \
		--timeout $(DEPLOY_TIMEOUT)s

helm-uninstall:
	helm uninstall $(RELEASE) \
		--kubeconfig "$(KUBECONFIG)" \
		$(if $(KUBE_CONTEXT),--kube-context $(KUBE_CONTEXT),) \
		--namespace $(NAMESPACE)
