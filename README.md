# build-kubernetes-cluster

A set of scripts to initialise a new standard Kubernetes cluster running Kubernetes 1.35 with Calico CNI.

## Requirements

- Ubuntu 24.04 or later on all nodes
- Root or sudo access
- Network connectivity between all nodes

## Architecture

- **Control Plane (Machine A)**: Single control plane node that manages the cluster
- **Worker Nodes (Machine B, C, ...)**: As many worker nodes as needed

## Scripts

| Script                  | Description                                                                              |
| ----------------------- | ---------------------------------------------------------------------------------------- |
| `install.sh`            | Main orchestrator - runs containerd and k8s installation, optionally initializes cluster |
| `install-containerd.sh` | Installs and configures containerd with SystemdCgroup                                    |
| `install-k8s.sh`        | Installs kubelet, kubeadm, kubectl and disables swap                                     |
| `install-cni.sh`        | Installs Calico v3.31.4 network plugin                                                   |

## Get Started

### Option 1: Clone the repository

```console
git clone https://github.com/OMikkel/build-kubernetes-cluster.git
cd build-kubernetes-cluster
chmod +x *.sh
./install.sh
```

### Option 2: Download main install script

```console
curl -O https://raw.githubusercontent.com/OMikkel/build-kubernetes-cluster/master/install.sh
curl -O https://raw.githubusercontent.com/OMikkel/build-kubernetes-cluster/master/install-containerd.sh
curl -O https://raw.githubusercontent.com/OMikkel/build-kubernetes-cluster/master/install-k8s.sh
curl -O https://raw.githubusercontent.com/OMikkel/build-kubernetes-cluster/master/install-cni.sh
chmod +x *.sh
./install.sh
```

## Installation Steps

The `install.sh` script performs the following:

1. **Install containerd** - Container runtime with SystemdCgroup enabled
2. **Install Kubernetes components** - kubelet, kubeadm, kubectl (held at current version)
3. **Initialize cluster** (control plane only) - Runs `kubeadm init` with specified pod CIDR
4. **Configure kubeconfig** (control plane only) - Sets up kubectl access for current user
5. **Install Calico CNI** (control plane only) - Deploys Calico v3.31.4 network plugin

## Joining Worker Nodes

After initializing the control plane, run the `kubeadm join` command shown in the output on each worker node.

## Verify Installation

```console
kubectl get nodes
watch kubectl get tigerastatus
```

---

## :warning: Known Installation Errors

### `E: Unable to locate package kubelet|kubeadm|kubectl`

Cause: Kubernetes apt repository was not configured on the host.

Status: Fixed in `install-k8s.sh` by adding the `pkgs.k8s.io` keyring and repo before package installation.

### `kubeadm: command not found` during control-plane init

Cause: Kubernetes packages were not installed (usually due to the repo issue above).

Status: `install.sh` now stops immediately if `install-k8s.sh` fails, so the script does not continue with a broken state.

### `kubectl: command not found` while installing Calico

Cause: CNI step started before Kubernetes components were installed or before kubeconfig/API access was ready.

Status: `install-cni.sh` now validates `kubectl` exists and that the Kubernetes API is reachable before continuing.
