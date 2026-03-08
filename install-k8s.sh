#!/usr/bin/env bash

set -Eeuo pipefail

KUBE_VERSION_RAW="${KUBE_VERSION:-1.35.2}"
KUBE_VERSION_CLEAN="${KUBE_VERSION_RAW#v}"

if [[ "$KUBE_VERSION_CLEAN" =~ ^([0-9]+)\.([0-9]+)(\.[0-9]+)?$ ]]; then
    K8S_CHANNEL="v${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
else
    echo "[ERR ] Invalid KUBE_VERSION format: ${KUBE_VERSION_RAW}. Expected like 1.35.2 or v1.35.2" >&2
    exit 1
fi

log_info() { echo "[INFO] $1"; }
log_step() { echo -e "\n[STEP] $1"; }
log_ok() { echo "[ OK ] $1"; }
log_error() { echo "[ERR ] $1" >&2; }

trap 'log_error "Kubernetes component setup failed near line $LINENO."' ERR

log_info "Starting Kubernetes component installation"

log_step "Install repository prerequisites"
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
log_ok "Prerequisites installed"

log_step "Configure Kubernetes apt repository (${K8S_CHANNEL})"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_CHANNEL}/deb/Release.key" | \
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_CHANNEL}/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
log_ok "Kubernetes repository configured"

log_step "Install kubelet, kubeadm, kubectl"
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl >/dev/null
log_ok "Kubernetes packages installed and pinned"

log_step "Verify installed versions"
_KUBELET_VERSION="$(kubelet --version | awk '{print $2}')"
_KUBECTL_VERSION="$(kubectl version --client --output=yaml 2>/dev/null | awk '/gitVersion:/ {print $2; exit}')"
_KUBEADM_VERSION="$(kubeadm version -o short 2>/dev/null || true)"

if [[ -z "$_KUBELET_VERSION" ]]; then
    log_error "Failed to verify kubelet installation"
    exit 1
fi
if [[ -z "$_KUBECTL_VERSION" ]]; then
    log_error "Failed to verify kubectl installation"
    exit 1
fi
if [[ -z "$_KUBEADM_VERSION" ]]; then
    log_error "Failed to verify kubeadm installation"
    exit 1
fi

log_ok "Kubelet version: $_KUBELET_VERSION"
log_ok "Kubectl version: $_KUBECTL_VERSION"
log_ok "Kubeadm version: $_KUBEADM_VERSION"

log_step "Disable swap (required by kubelet)"
sudo swapoff -a
sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

if [[ -n "$(sudo swapon --show --noheadings 2>/dev/null || true)" ]]; then
    log_error "Swap is still enabled"
    exit 1
fi
log_ok "Swap disabled"

log_step "Enable kubelet service"
sudo systemctl enable kubelet >/dev/null
log_ok "kubelet enabled"

