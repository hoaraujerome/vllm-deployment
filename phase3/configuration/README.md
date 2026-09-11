# Phase 3 WireGuard Configuration

This directory contains WireGuard server bootstrap and client configuration tooling.

## Files

- `wireguard-server-cloud-init.yaml` — Cloud-init script applied to EC2 via user_data
- `generate-client-config.sh` — Helper to create laptop/device WireGuard configs
- `keys/` — WireGuard private/public keys (gitignored)
- `client-configs/` — Generated client .conf files (gitignored)

## Workflow

### 1. Deploy infrastructure

```bash
cd /path/to/vllm-deployment/phase3
make check-provisioning RUN_PROVISIONING_APPLY=1
```

The cloud-init script will:
- Install WireGuard
- Generate server keys
- Create `/etc/wireguard/wg0.conf` with server config
- Enable IP forwarding
- Configure iptables for VPC routing
- Start `wg-quick@wg0.service`

### 2. Get server info

```bash
make wireguard-info
```

This shows the server EIP, K8s node IP, and your current home IP.

### 3. Get server public key

```bash
make wireguard-server-key
```

This SSHs to the server and fetches `/etc/wireguard/server.pub`.

### 4. Generate client config

```bash
make wireguard-client-config
```

This runs `./configuration/generate-client-config.sh` with the server EIP automatically.

This creates:
- `keys/laptop.key` — client private key
- `keys/laptop.pub` — client public key  
- `client-configs/laptop.conf` — WireGuard client config

### 5. Add peer to server

Follow the script output to add the peer block to `/etc/wireguard/wg0.conf` on the server and restart the service.

### 6. Connect from laptop

```bash
# macOS/Linux
wg-quick up client-configs/laptop.conf

# Or install system-wide
sudo cp client-configs/laptop.conf /etc/wireguard/laptop.conf
sudo wg-quick up laptop

# Verify
wg show
ping 10.8.0.1          # WireGuard server VPN IP
ping <k8s-node-ip>     # K8s node private IP (from Terraform output)
```

### 7. Run validation

```bash
cd ../../..
make check-vpn
```

Gate 4 should pass once WireGuard is connected.

## Troubleshooting

### Check server logs

```bash
ssh ubuntu@${SERVER_EIP} sudo journalctl -u wg-quick@wg0 -f
```

### Check cloud-init logs

```bash
ssh ubuntu@${SERVER_EIP} sudo cat /var/log/cloud-init-output.log
ssh ubuntu@${SERVER_EIP} sudo cat /var/log/wireguard-init.log
```

### Manual WireGuard commands

```bash
# On server
sudo wg show
sudo systemctl status wg-quick@wg0

# On client
wg show
wg-quick down laptop
wg-quick up client-configs/laptop.conf
```

## Security notes

- All keys and configs are gitignored
- Server private key lives only on the EC2 instance
- Client private keys live only on client devices
- Use SSH public key auth to access the server
- WireGuard SG restricts UDP 51820 to your home IP (dynamically fetched)

## References

- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)
- [Phase 3 README](../README.md)
- [Obsidian notes](~/Library/Mobile Documents/iCloud~md~obsidian/Documents/secondbrain/coding/1-projects/vllm-deployment/Phase 3 — WireGuard Access.md)
