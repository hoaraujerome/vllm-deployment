# Phase 3 WireGuard Deployment — Quick Start

This guide walks through deploying WireGuard and connecting from your laptop.

## Prerequisites

- Phase 2 cluster running (`cd ../phase2 && make check-cluster`)
- `terraform` or `tofu` installed
- `wg` (WireGuard tools) installed on laptop
- AWS credentials configured (`AWS_PROFILE=k8s_homelab`)

## Steps

### 1. Deploy WireGuard server

```bash
cd phase3
make check-provisioning RUN_PROVISIONING_APPLY=1
```

This:
- Creates WireGuard EC2 instance (`t4g.nano`)
- Attaches Elastic IP
- Runs cloud-init to install and configure WireGuard
- Adds security group rule for K8s API access

Wait ~2-3 minutes for cloud-init to complete.

### 2. Get server info

```bash
make wireguard-info
```

Example output:
```
WireGuard Server Info:

  Server EIP:        3.96.123.45
  K8s node IP:       10.60.1.100
  Your home IP:      24.37.xxx.xxx/32
```

### 3. Fetch server public key

```bash
make wireguard-server-key
```

Example output:
```
Fetching WireGuard server public key...
abcd1234efgh5678ijkl9012mnop3456qrst7890uvwx1234yzab5678=
```

Copy this public key for the next step.

### 4. Generate laptop client config

```bash
make wireguard-client-config
```

This script will:
1. Generate laptop private/public keys
2. Prompt for server public key (paste from step 3)
3. Create `configuration/client-configs/laptop.conf`
4. Show commands to add the peer to the server

Follow the output to:
1. SSH to server and add the `[Peer]` block
2. Restart WireGuard on server
3. Connect from laptop

### 5. Add peer to server

```bash
SERVER_EIP=$(cd vpn/infra/main-account/ca-central-1/prod && terraform output -raw wireguard_public_ip)
CLIENT_PUBLIC_KEY=$(cat configuration/keys/laptop.pub)

ssh ubuntu@${SERVER_EIP} sudo tee -a /etc/wireguard/wg0.conf <<EOF

[Peer]
# laptop
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = 10.8.0.2/32
EOF

ssh ubuntu@${SERVER_EIP} sudo systemctl restart wg-quick@wg0
```

### 6. Connect from laptop

```bash
# Option A: Direct (requires sudo)
sudo wg-quick up configuration/client-configs/laptop.conf

# Option B: Install system-wide
sudo mkdir -p /etc/wireguard
sudo cp configuration/client-configs/laptop.conf /etc/wireguard/laptop.conf
sudo chmod 600 /etc/wireguard/laptop.conf
sudo wg-quick up laptop
```

### 7. Verify connection

```bash
# Check WireGuard status
wg show

# Ping WireGuard server VPN IP
ping -c 3 10.8.0.1

# Ping K8s node (get IP from step 2)
K8S_NODE_IP=$(cd vpn/infra/main-account/ca-central-1/prod && terraform output -raw k8s_node_private_ip)
ping -c 3 ${K8S_NODE_IP}
```

Expected output for `wg show`:
```
interface: utun4
  public key: ...
  private key: (hidden)
  listening port: 51234

peer: abcd1234...
  endpoint: 3.96.123.45:51820
  allowed ips: 10.8.0.0/24, 10.60.0.0/16
  latest handshake: 30 seconds ago
  transfer: 1.2 KiB received, 980 B sent
```

### 8. Fetch kubeconfig (one-time)

```bash
make fetch-kubeconfig
```

Maps API hostname for TLS (kubeadm uses `k8scp`):

```bash
K8S_NODE_IP=$(cd vpn/infra/main-account/ca-central-1/prod && terraform output -raw k8s_node_private_ip)
echo "${K8S_NODE_IP} k8scp" | sudo tee -a /etc/hosts
```

### 9. Runtime validation

```bash
make check-vpn
```

Gates 4–6: WireGuard up, `kubectl get nodes` from laptop, no EICE in phase3 scripts.

### 10. Full validation (greenfield / reprovision)

```bash
make check-full RUN_PROVISIONING_APPLY=1
```

All gates 1–6 should pass.

## Troubleshooting

### WireGuard won't connect

```bash
# Check server logs
SERVER_EIP=$(cd vpn/infra/main-account/ca-central-1/prod && terraform output -raw wireguard_public_ip)
ssh ubuntu@${SERVER_EIP} sudo journalctl -u wg-quick@wg0 -n 50

# Check cloud-init logs
ssh ubuntu@${SERVER_EIP} sudo cat /var/log/cloud-init-output.log
ssh ubuntu@${SERVER_EIP} sudo tail -100 /var/log/wireguard-init.log
```

### Can't SSH to server

- Check security group allows SSH from your IP (`make wireguard-info`)
- Verify SSH key: `ssh-add -L | grep k8s_homelab`
- Try EICE if direct SSH fails (Phase 2 break-glass still works)

### No handshake in `wg show`

- Verify server peer config matches client public key
- Check UDP 51820 not blocked by firewall
- Try `sudo wg-quick down laptop && sudo wg-quick up laptop`

### Can ping 10.8.0.1 but not K8s node

- Check IP forwarding on server: `ssh ubuntu@${SERVER_EIP} cat /proc/sys/net/ipv4/ip_forward` (should be 1)
- Check iptables: `ssh ubuntu@${SERVER_EIP} sudo iptables -t nat -L POSTROUTING -v`
- Check K8s SG allows 6443 from WireGuard SG

## Daily usage

```bash
# Connect
sudo wg-quick up laptop

# Disconnect
sudo wg-quick down laptop

# Status
wg show

# Use kubectl
export KUBECONFIG=~/.kube/vllm-phase2.conf
kubectl get pods -A
```

## References

- [configuration/README.md](configuration/README.md) — detailed config docs
- [Phase 3 README](README.md) — architecture and constraints
- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)
