#!/usr/bin/env bash

set -Eeuo pipefail

log_info() { echo "[INFO] $1"; }
log_step() { echo -e "\n[STEP] $1"; }
log_ok() { echo "[ OK ] $1"; }
log_error() { echo "[ERR ] $1" >&2; }

trap 'log_error "Containerd setup failed near line $LINENO."' ERR

log_info "Starting containerd installation"

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
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update -y
sudo apt-get remove -y containerd runc || true
sudo apt-get install -y containerd.io

rm -f /etc/containerd/config.toml
sudo systemctl restart containerd
log_ok "containerd.io package installed"

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

CONTAINERD_VERSION="$(containerd --version 2>/dev/null || true)"
if [[ -n "$CONTAINERD_VERSION" ]]; then
	log_info "Detected runtime: ${CONTAINERD_VERSION}"
fi

log_step "Verify containerd installation"
if [[ ! -S /run/containerd/containerd.sock ]]; then
	log_error "containerd socket not found at /run/containerd/containerd.sock"
	exit 1
fi

if ! ctr version >/dev/null 2>&1; then
	log_error "ctr could not talk to containerd"
	exit 1
fi

PLUGIN_LIST="$(sudo ctr plugins ls 2>/dev/null || true)"
CRI_RUNTIME_LINE="$(awk '$1=="io.containerd.cri.v1"&&$2=="runtime" || $1=="io.containerd.grpc.v1"&&$2=="cri" { print; exit }' <<<"$PLUGIN_LIST")"

if [[ -z "$CRI_RUNTIME_LINE" ]]; then
	log_error "CRI runtime plugin not detected in containerd. kubeadm will fail to connect to RuntimeService."
	if [[ -n "$PLUGIN_LIST" ]]; then
		echo "$PLUGIN_LIST"
	else
		sudo ctr plugins ls || true
	fi
	exit 1
fi

if ! grep -Eq '\bok\b' <<<"$CRI_RUNTIME_LINE"; then
	log_error "CRI runtime plugin found but not healthy: $CRI_RUNTIME_LINE"
	sudo ctr plugins ls || true
	exit 1
fi

log_ok "containerd socket is available"
log_ok "ctr can communicate with containerd"
log_ok "CRI plugin is available"

log_ok "Containerd installation complete"
