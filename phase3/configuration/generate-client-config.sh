#!/usr/bin/env bash
# Generate WireGuard client configuration for laptop/device
# Usage: ./generate-client-config.sh <client-name> <server-eip> [ssh-key-path]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYS_DIR="${SCRIPT_DIR}/keys"
CLIENT_CONFIGS_DIR="${SCRIPT_DIR}/client-configs"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <client-name> <server-eip> [ssh-key-path]"
  echo "Example: $0 laptop 3.96.123.45"
  echo "         $0 laptop 3.96.123.45 ~/.ssh/id_rsa_k8s_homelab"
  exit 1
fi

CLIENT_NAME="$1"
SERVER_EIP="$2"
SSH_KEY="${3:-${HOME}/.ssh/id_rsa_k8s_homelab}"
VPN_NETWORK="10.8.0.0/24"
VPC_CIDR="10.60.0.0/16"
WG_PORT="51820"

# Create directories if they don't exist
mkdir -p "${KEYS_DIR}" "${CLIENT_CONFIGS_DIR}"

CLIENT_PRIVATE_KEY_FILE="${KEYS_DIR}/${CLIENT_NAME}.key"
CLIENT_PUBLIC_KEY_FILE="${KEYS_DIR}/${CLIENT_NAME}.pub"
CLIENT_CONFIG_FILE="${CLIENT_CONFIGS_DIR}/${CLIENT_NAME}.conf"

# Generate client keys if they don't exist
if [[ ! -f "${CLIENT_PRIVATE_KEY_FILE}" ]]; then
  echo "==> Generating keys for ${CLIENT_NAME}..."
  wg genkey | tee "${CLIENT_PRIVATE_KEY_FILE}" | wg pubkey > "${CLIENT_PUBLIC_KEY_FILE}"
  chmod 600 "${CLIENT_PRIVATE_KEY_FILE}"
  chmod 644 "${CLIENT_PUBLIC_KEY_FILE}"
else
  echo "==> Keys for ${CLIENT_NAME} already exist"
fi

CLIENT_PRIVATE_KEY="$(cat "${CLIENT_PRIVATE_KEY_FILE}")"
CLIENT_PUBLIC_KEY="$(cat "${CLIENT_PUBLIC_KEY_FILE}")"

# Assign next available IP (simple: 10.8.0.2 for first client, etc.)
# TODO: track used IPs more robustly if multiple clients
CLIENT_IP="10.8.0.2/32"

# Fetch server public key from Terraform output or prompt
echo ""
echo "==> Fetching server public key..."
if [[ -f "${SSH_KEY}" ]]; then
  echo "Attempting SSH to ${SERVER_EIP} with key ${SSH_KEY}..."
  if SERVER_PUBLIC_KEY=$(ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "ubuntu@${SERVER_EIP}" sudo cat /etc/wireguard/server.pub 2>/dev/null); then
    echo "Server public key fetched: ${SERVER_PUBLIC_KEY}"
  else
    echo ""
    echo "WARNING: Cannot SSH to server automatically. This might be because:"
    echo "  1. Cloud-init is still running (wait 2-3 minutes after apply)"
    echo "  2. Wrong SSH key"
    echo "  3. Security group doesn't allow your current IP"
    echo ""
    read -p "Enter server public key manually: " SERVER_PUBLIC_KEY
  fi
else
  echo ""
  echo "SSH key not found: ${SSH_KEY}"
  echo "Run this command to get the server public key:"
  echo ""
  echo "  ssh -i YOUR_KEY ubuntu@${SERVER_EIP} sudo cat /etc/wireguard/server.pub"
  echo ""
  read -p "Enter server public key: " SERVER_PUBLIC_KEY
fi

# Generate client config
cat > "${CLIENT_CONFIG_FILE}" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}
DNS = 10.60.0.2

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER_EIP}:${WG_PORT}
AllowedIPs = ${VPN_NETWORK}, ${VPC_CIDR}
PersistentKeepalive = 25
EOF

chmod 600 "${CLIENT_CONFIG_FILE}"

echo ""
echo "==> Client config created: ${CLIENT_CONFIG_FILE}"
echo ""
echo "==> Next steps:"
echo ""
echo "1. Add this peer to the server wg0.conf:"
echo ""
echo "   ssh -i ${SSH_KEY} ubuntu@${SERVER_EIP} sudo tee -a /etc/wireguard/wg0.conf <<EOF"
echo ""
echo "   [Peer]"
echo "   # ${CLIENT_NAME}"
echo "   PublicKey = ${CLIENT_PUBLIC_KEY}"
echo "   AllowedIPs = ${CLIENT_IP}"
echo "   EOF"
echo ""
echo "2. Restart WireGuard on the server:"
echo ""
echo "   ssh -i ${SSH_KEY} ubuntu@${SERVER_EIP} sudo systemctl restart wg-quick@wg0"
echo ""
echo "3. On your laptop/device:"
echo ""
echo "   wg-quick up ${CLIENT_CONFIG_FILE}"
echo "   # or: sudo cp ${CLIENT_CONFIG_FILE} /etc/wireguard/${CLIENT_NAME}.conf && sudo wg-quick up ${CLIENT_NAME}"
echo ""
echo "4. Verify the connection:"
echo ""
echo "   wg show"
echo "   ping 10.8.0.1       # WireGuard server VPN IP"
echo "   ping 10.60.1.x      # K8s node private IP"
echo ""
