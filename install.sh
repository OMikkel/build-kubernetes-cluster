#!/bin/bash

CALICO_VERSION="v3.31.4"
KUBE_VERSION="1.35.0"

echo "Installing kubernetes 1.35 for Ubuntu 24.04"

# Step 1: Install containerd
echo "Step 1: Installing containerd"
bash install-containerd.sh

# Step 2: Install kubernetes components
echo "Step 2: Installing kubernetes components"
bash install-k8s.sh

echo "Kubernetes components installed successfully"

read -p "Is this a control-plane node? (y/n) " IS_CONTROL_PLANE
if [[ "$IS_CONTROL_PLANE" == "y" || "$IS_CONTROL_PLANE" == "Y" ]]
then
    read -p "Enter the desired CIDR for the pod network (default: 192.168.0.0/16): " CLUSTER_CIDR
    CLUSTER_CIDR=${CLUSTER_CIDR:-192.168.0.0/16}

    # Step 3: Initialize Kubernetes cluster with kubeadm
    echo "Step 3: Initializing Kubernetes cluster with kubeadm"
    sudo kubeadm init --pod-network-cidr=$CLUSTER_CIDR --kubernetes-version=$KUBE_VERSION
    echo "Kubernetes cluster initialized successfully"

    # Step 4: Set up kubeconfig for the current user
    echo "Step 4: Setting up kubeconfig for the current user"
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    echo "Kubeconfig set up successfully"

    # Step 5: Install Calico network plugin
    echo "Step 5: Installing Calico network plugin"
    CLUSTER_CIDR=${CLUSTER_CIDR:-192.168.0.0/16}
    bash install-cni.sh
else
    echo "Skipping cluster initialization since this is not a control-plane node"
    echo "Please run 'kubeadm join' on this node to join the cluster after initializing the control-plane node"
fi
