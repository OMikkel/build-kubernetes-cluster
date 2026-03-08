#!/usr/bin/env bash

set -Eeuo pipefail

CALICO_VERSION="${CALICO_VERSION:-v3.31.4}"

log_info() { echo "[INFO] $1"; }
log_step() { echo -e "\n[STEP] $1"; }
log_ok() { echo "[ OK ] $1"; }
log_error() { echo "[ERR ] $1" >&2; }

trap 'log_error "Calico installation failed near line $LINENO."' ERR

log_info "Starting Calico installation (${CALICO_VERSION})"

if ! command -v kubectl >/dev/null 2>&1; then
    log_error "kubectl is not installed. Run install-k8s.sh first."
    exit 1
fi

# Ensure kubectl has a kubeconfig in script/non-interactive contexts
if [[ -z "${KUBECONFIG:-}" && -f "$HOME/.kube/config" ]]; then
    export KUBECONFIG="$HOME/.kube/config"
elif [[ -z "${KUBECONFIG:-}" && -f /etc/kubernetes/admin.conf ]]; then
    export KUBECONFIG=/etc/kubernetes/admin.conf
fi

log_step "Wait for Kubernetes API to become reachable"
API_READY=0
for attempt in {1..24}; do
    if kubectl cluster-info >/dev/null 2>&1; then
        API_READY=1
        break
    fi
    sleep 5
done

if [[ "$API_READY" -ne 1 ]]; then
    log_error "Kubernetes API is not reachable after waiting 120 seconds."
    log_info "Try: kubectl --kubeconfig /etc/kubernetes/admin.conf cluster-info"
    exit 1
fi
log_ok "Kubernetes API reachable"

log_step "Install Calico operator CRDs"
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/operator-crds.yaml"
log_ok "CRDs applied"

log_step "Install Tigera operator"
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"
log_ok "Tigera operator applied"

log_step "Download Calico custom resources"
curl -fsSLo custom-resources.yaml "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"

if [[ ! -f custom-resources.yaml ]]; then
    log_error "Failed to download custom-resources.yaml"
    exit 1
fi
log_ok "custom-resources.yaml downloaded"

if [[ -z "${CLUSTER_CIDR:-}" ]]; then
    read -rp "Enter the desired CIDR for the pod network (default: 192.168.0.0/16): " CLUSTER_CIDR
fi
CLUSTER_CIDR=${CLUSTER_CIDR:-192.168.0.0/16}

log_step "Set pod network CIDR to ${CLUSTER_CIDR}"
sed -i "s#192.168.0.0/16#${CLUSTER_CIDR}#g" custom-resources.yaml
log_ok "CIDR updated"

log_step "Apply Calico custom resources"
kubectl apply -f custom-resources.yaml
log_ok "Calico installed successfully"

log_info "Check status with: watch kubectl get tigerastatus"

