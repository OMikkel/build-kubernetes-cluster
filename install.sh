#!/usr/bin/env bash

set -Eeuo pipefail

CALICO_VERSION="${CALICO_VERSION:-v3.31.4}"
KUBE_VERSION="${KUBE_VERSION:-1.35.2}"

log_info() { echo "[INFO] $1"; }
log_step() { echo -e "\n[STEP] $1"; }
log_ok() { echo "[ OK ] $1"; }
log_error() { echo "[ERR ] $1" >&2; }

trap 'log_error "Installation failed near line $LINENO."' ERR



read -p "Please enter the desired Kubernetes version (default: ${KUBE_VERSION}): " KUBE_VERSION
KUBE_VERSION=${KUBE_VERSION:-$KUBE_VERSION}
read -p "Please enter the desired Calico version (default: ${CALICO_VERSION}): " CALICO_VERSION
CALICO_VERSION=${CALICO_VERSION:-$CALICO_VERSION}

read -rp "This script will install Kubernetes ${KUBE_VERSION} with Calico ${CALICO_VERSION}. Do you want to proceed? (y/n) " PROCEED
if [[ "$PROCEED" != "y" && "$PROCEED" != "Y" ]]; then
    log_info "Installation aborted by user."
    exit 0
fi

log_info "Installing Kubernetes ${KUBE_VERSION}"

log_step "1/5 Install containerd"
bash install-containerd.sh
log_ok "Containerd installed"

log_step "2/5 Install Kubernetes components"
KUBE_VERSION="$KUBE_VERSION" bash install-k8s.sh
log_ok "Kubernetes components installed"

read -rp "Is this a control-plane node? (y/n) " IS_CONTROL_PLANE
if [[ "$IS_CONTROL_PLANE" == "y" || "$IS_CONTROL_PLANE" == "Y" ]]; then
    read -rp "Enter the desired CIDR for the pod network (default: 192.168.0.0/16): " CLUSTER_CIDR
    CLUSTER_CIDR=${CLUSTER_CIDR:-192.168.0.0/16}
    KUBEADM_K8S_VERSION="v${KUBE_VERSION#v}"

    log_step "3/5 Initialize Kubernetes control-plane"
    KUBEADM_CONFIG_FILE="$(mktemp /tmp/kubeadm-config.XXXXXX.yaml)"
    cat >"$KUBEADM_CONFIG_FILE" <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: ${KUBEADM_K8S_VERSION}
networking:
  podSubnet: ${CLUSTER_CIDR}
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF

    sudo kubeadm init --config "$KUBEADM_CONFIG_FILE"
    rm -f "$KUBEADM_CONFIG_FILE"
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
