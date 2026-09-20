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

.PHONY: help check check-gates check-toolchain check-provisioning check-vpn check-full pre-commit \
	fetch-kubeconfig wireguard-info wireguard-server-key wireguard-client-config destroy

# --- AWS / Terraform defaults ---
export AWS_PROFILE ?= k8s_homelab
export AWS_REGION ?= ca-central-1
export KUBECONFIG ?= $(HOME)/.kube/vllm-phase2.conf
export SSH_PRIVATE_KEY_PATH ?= $(HOME)/.ssh/id_rsa_k8s_homelab
export K8S_CONTROL_PLANE_HOST ?= k8scp
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
	@echo "  fetch-kubeconfig         fetch admin.conf via WireGuard SSH hop"
	@echo "  wireguard-info           show WireGuard server EIP and K8s node IP"
	@echo "  wireguard-server-key     fetch WireGuard server public key (requires VPN/SSH)"
	@echo "  wireguard-client-config  generate WireGuard client config (interactive)"
	@echo "  destroy                  destroy Phase 3 WireGuard infrastructure (requires confirmation)"
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

fetch-kubeconfig:
	./scripts/fetch-kubeconfig.sh

wireguard-info:
	@echo "WireGuard Server Info:"
	@echo ""
	@cd vpn/infra/main-account/ca-central-1/prod && \
		echo "  Server EIP:        $$(terraform output -raw wireguard_public_ip 2>/dev/null || echo 'not deployed')" && \
		echo "  K8s node IP:       $$(terraform output -raw k8s_node_private_ip 2>/dev/null || echo 'not deployed')" && \
		echo "  Your home IP:      $$(terraform output -raw current_home_ip 2>/dev/null || echo 'not deployed')"
	@echo ""
	@echo "Next: make wireguard-server-key"

wireguard-server-key:
	@echo "Fetching WireGuard server public key..."
	@echo ""
	@cd vpn/infra/main-account/ca-central-1/prod && \
	SERVER_EIP=$$(terraform output -raw wireguard_public_ip 2>/dev/null); \
	SSH_KEY=$$(terraform output -raw ssh_private_key_path 2>/dev/null || echo "~/.ssh/id_rsa_k8s_homelab"); \
	if [[ -z "$$SERVER_EIP" ]]; then \
		echo "ERROR: Server not deployed. Run: make check-provisioning RUN_PROVISIONING_APPLY=1"; \
		exit 1; \
	fi; \
	SSH_KEY_EXPANDED=$$(eval echo "$$SSH_KEY"); \
	if [[ ! -f "$$SSH_KEY_EXPANDED" ]]; then \
		echo "ERROR: SSH private key not found: $$SSH_KEY_EXPANDED"; \
		echo "Check ssh_private_key_path in terraform.tfvars or update SSH_KEY in Makefile"; \
		exit 1; \
	fi; \
	echo "Connecting to $$SERVER_EIP with key $$SSH_KEY_EXPANDED..."; \
	ssh -i "$$SSH_KEY_EXPANDED" -o StrictHostKeyChecking=accept-new "ubuntu@$$SERVER_EIP" sudo cat /etc/wireguard/server.pub 2>/dev/null || \
		(echo ""; echo "ERROR: Cannot SSH to server. Check:"; \
		 echo "  1. Server is running (cloud-init may still be in progress - wait 2-3 min)"; \
		 echo "  2. Security group allows SSH from your IP: $$(terraform output -raw current_home_ip 2>/dev/null)"; \
		 echo "  3. SSH key is correct: $$SSH_KEY_EXPANDED"; \
		 echo ""; \
		 echo "Troubleshooting:"; \
		 echo "  ssh -v -i $$SSH_KEY_EXPANDED ubuntu@$$SERVER_EIP"; \
		 echo "  ssh -i $$SSH_KEY_EXPANDED ubuntu@$$SERVER_EIP sudo journalctl -u cloud-init -n 50"; \
		 exit 1)
	@echo ""
	@echo "Next: make wireguard-client-config"

wireguard-client-config:
	@SERVER_EIP=$$(cd vpn/infra/main-account/ca-central-1/prod && terraform output -raw wireguard_public_ip 2>/dev/null); \
	if [[ -z "$$SERVER_EIP" ]]; then \
		echo "ERROR: Server not deployed. Run: make check-provisioning RUN_PROVISIONING_APPLY=1"; \
		exit 1; \
	fi; \
	./configuration/generate-client-config.sh laptop "$$SERVER_EIP"

destroy:
	@echo "This will destroy Phase 3 WireGuard infrastructure:"
	@echo ""
	@echo "  - WireGuard EC2 instance"
	@echo "  - Elastic IP"
	@echo "  - Security groups and rules"
	@echo "  - SSH key pair"
	@echo ""
	@echo "Phase 2 cluster (K8s node, VPC, EICE) will NOT be touched."
	@echo ""
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [[ "$$confirm" != "yes" ]]; then \
		echo "Destroy cancelled."; \
		exit 0; \
	fi; \
	echo ""; \
	echo "Destroying Phase 3 infrastructure..."; \
	cd vpn/infra/main-account/ca-central-1/prod && terraform destroy
