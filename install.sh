#!/usr/bin/env bash

set -Eeuo pipefail

CALICO_VERSION="${CALICO_VERSION:-v3.31.4}"
KUBE_VERSION="${KUBE_VERSION:-1.35.0}"

log_info() { echo "[INFO] $1"; }
log_step() { echo -e "\n[STEP] $1"; }
log_ok() { echo "[ OK ] $1"; }
log_error() { echo "[ERR ] $1" >&2; }

trap 'log_error "Installation failed near line $LINENO."' ERR

log_info "Installing Kubernetes ${KUBE_VERSION} on Ubuntu 24.04"

log_step "1/5 Install containerd"
bash install-containerd.sh
log_ok "Containerd installed"

log_step "2/5 Install Kubernetes components"
bash install-k8s.sh
log_ok "Kubernetes components installed"

read -rp "Is this a control-plane node? (y/n) " IS_CONTROL_PLANE
if [[ "$IS_CONTROL_PLANE" == "y" || "$IS_CONTROL_PLANE" == "Y" ]]; then
    read -rp "Enter the desired CIDR for the pod network (default: 192.168.0.0/16): " CLUSTER_CIDR
    CLUSTER_CIDR=${CLUSTER_CIDR:-192.168.0.0/16}

    log_step "3/5 Initialize Kubernetes control-plane"
    sudo kubeadm init --pod-network-cidr="$CLUSTER_CIDR" --kubernetes-version="$KUBE_VERSION"
    log_ok "Control-plane initialized"

    log_step "4/5 Configure kubeconfig for current user"
    mkdir -p "$HOME/.kube"
    sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
    sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
    log_ok "Kubeconfig configured"

    log_step "5/5 Install Calico CNI"
    CLUSTER_CIDR="$CLUSTER_CIDR" CALICO_VERSION="$CALICO_VERSION" bash install-cni.sh
    log_ok "Calico installed"

    echo -e "\n[ OK ] Cluster setup completed successfully."
else
    log_info "Skipping control-plane initialization on this node."
    log_info "Run the kubeadm join command from the control-plane output to join as worker."
fi
