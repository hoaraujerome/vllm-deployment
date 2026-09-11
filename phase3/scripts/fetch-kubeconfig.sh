#!/usr/bin/env bash
# Fetch kubeadm admin.conf for laptop kubectl via WireGuard EC2 TCP forward.
#
# Usage (from devbox shell, phase3/):
#   make fetch-kubeconfig
#
# Env:
#   AWS_PROFILE, AWS_REGION
#   KUBECONFIG                — destination (default ~/.kube/vllm-phase2.conf)
#   SSH_PRIVATE_KEY_PATH      — default ~/.ssh/id_rsa_k8s_homelab
#   K8S_CONTROL_PLANE_HOST    — default k8scp (Phase 2 kubeadm controlPlaneEndpoint)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PHASE3_VPN_TF_DIR="${PHASE3_DIR}/vpn/infra/main-account/ca-central-1/prod"
AWS_PROFILE="${AWS_PROFILE:-k8s_homelab}"
AWS_REGION="${AWS_REGION:-ca-central-1}"
KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/vllm-phase2.conf}"
SSH_PRIVATE_KEY_PATH="${SSH_PRIVATE_KEY_PATH:-${HOME}/.ssh/id_rsa_k8s_homelab}"
K8S_CONTROL_PLANE_HOST="${K8S_CONTROL_PLANE_HOST:-k8scp}"

info() { echo "==> $*" >&2; }
fail() { echo "ERROR: $*" >&2; exit 1; }

command -v ssh >/dev/null 2>&1 || fail "missing ssh (run devbox shell)"
command -v terraform >/dev/null 2>&1 || fail "missing terraform (run devbox shell)"

SSH_PRIVATE_KEY_PATH="$(eval echo "${SSH_PRIVATE_KEY_PATH}")"
[[ -f "${SSH_PRIVATE_KEY_PATH}" ]] || fail "SSH private key not found: ${SSH_PRIVATE_KEY_PATH}"

export AWS_PROFILE
export AWS_DEFAULT_REGION="${AWS_REGION}"

k8s_node_ip="$(terraform -chdir="${PHASE3_VPN_TF_DIR}" output -raw k8s_node_private_ip 2>/dev/null)" || {
  fail "k8s_node_private_ip output missing — apply phase3 VPN live root first"
}
wireguard_eip="$(terraform -chdir="${PHASE3_VPN_TF_DIR}" output -raw wireguard_public_ip 2>/dev/null)" || {
  fail "wireguard_public_ip output missing — apply phase3 VPN live root first"
}

# ProxyCommand -W: jump host only forwards TCP; laptop key authenticates to both hops.
jump_proxy_cmd="ssh -i ${SSH_PRIVATE_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -W %h:%p ubuntu@${wireguard_eip}"

info "Fetching admin.conf via WireGuard hop (${wireguard_eip} → ${k8s_node_ip})"
admin_conf="$(ssh -i "${SSH_PRIVATE_KEY_PATH}" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=accept-new \
  -o "ProxyCommand=${jump_proxy_cmd}" \
  "ubuntu@${k8s_node_ip}" \
  "sudo cat /etc/kubernetes/admin.conf")"

[[ -n "${admin_conf}" ]] || fail "failed to fetch admin.conf"

mkdir -p "$(dirname "${KUBECONFIG}")"
printf '%s\n' "${admin_conf}" >"${KUBECONFIG}"
chmod 600 "${KUBECONFIG}"

info "Wrote ${KUBECONFIG}"
echo ""
info "Next (one-time on laptop — API cert is for ${K8S_CONTROL_PLANE_HOST}):"
echo "  echo '${k8s_node_ip} ${K8S_CONTROL_PLANE_HOST}' | sudo tee -a /etc/hosts"
echo ""
info "Then connect WireGuard and run:"
echo "  kubectl --kubeconfig=${KUBECONFIG} get nodes"
