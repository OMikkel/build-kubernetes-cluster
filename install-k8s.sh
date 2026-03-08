#!/bin/bash

echo "Starting installation of kubernetes components for Ubuntu 24.04"

sudo apt update
echo "Installing: kubelet, kubeadm, kubectl"
sudo apt -y install kubelet kubeadm kubectl

echo "Holding: kubelet, kubeadm, kubectl"
sudo apt-mark hold kubelet kubeadm kubectl

_KUBELET_VERSION=$(kubelet --version | grep -Po '(?<=Kubernetes )[^ ]+')
_KUBECTL_VERSION=$(kubectl version | grep -Po '(?<=Client Version: )[^ ]+')
_KUBEADM_VERSION=$(kubeadm version | grep -Po '(?<=GitVersion:")[^"]+')
if [[ $_KUBELET_VERSION = "" ]] 
then
    echo "Failed to install kubelet"
    exit 1
fi
if [[ $_KUBECTL_VERSION = "" ]]
then
    echo "Failed to install kubectl"
    exit 1
fi
if [[ $_KUBEADM_VERSION = "" ]]
then
    echo "Failed to install kubeadm"
    exit 1
fi
if [[ $_KUBELET_VERSION != "" && $_KUBECTL_VERSION != "" && $_KUBEADM_VERSION != "" ]]
then
    echo "Kubernetes installed successfully"
    echo "Kubelet version: $_KUBELET_VERSION"
    echo "Kubectl version: $_KUBECTL_VERSION"
    echo "Kubeadm version: $_KUBEADM_VERSION"
fi

# Disable swap
echo "Disabling swap"
sudo swapoff -a

# Permanently disable it by commenting out the swap entry in /etc/fstab
sudo sed -i '/ swap / s/^/#/' /etc/fstab

if [[ "$(free -h | grep -Po '(0B)' | tr '\n' ' ')" != "0B 0B 0B " ]]
then
    echo "Failed to disable swap"
    exit 1
fi

sudo systemctl enable kubelet

