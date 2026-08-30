locals {
  tag_prefix = "vllm-phase3-vpn-"

  wireguard_node_name = "wireguard"
  ssh_port            = 22
  http_port           = 80
  https_port          = 443
  wireguard_port      = 51820
  k8s_api_port        = 6443
  tcp_protocol        = "tcp"
  udp_protocol        = "udp"
  anywhere_ipv4       = "0.0.0.0/0"
}
