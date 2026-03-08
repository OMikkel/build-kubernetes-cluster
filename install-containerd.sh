#!/usr/bin/env bash

set -Eeuo pipefail

log_info() { echo "[INFO] $1"; }
log_step() { echo -e "\n[STEP] $1"; }
log_ok() { echo "[ OK ] $1"; }
log_error() { echo "[ERR ] $1" >&2; }

trap 'log_error "Containerd setup failed near line $LINENO."' ERR

log_info "Starting containerd installation for Ubuntu 24.04"

log_step "Load required kernel modules"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
log_ok "Kernel modules loaded"

log_step "Configure required sysctl settings"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system >/dev/null
log_ok "Kernel networking configured"

log_step "Install containerd package"
sudo apt-get update -y
sudo apt-get -y install containerd
log_ok "Containerd package installed"

log_step "Configure containerd"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
log_ok "Containerd configuration written"

log_step "Enable and restart containerd service"
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

if sudo systemctl is-active --quiet containerd; then
	log_ok "containerd is active"
else
	sudo systemctl --no-pager status containerd || true
	log_error "containerd service is not active"
	exit 1
fi

log_ok "Containerd installation complete"