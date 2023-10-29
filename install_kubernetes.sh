

# Install kubernetes
echo "Installing: curl, apt-transport-https"
sudo apt -y install curl apt-transport-https
curl  -fsSL  https://packages.cloud.google.com/apt/doc/apt-key.gpg|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
echo "Installing: kubelet, kubeadm, kubectl, git, vim, wget"
sudo apt -y install vim git wget kubelet kubeadm kubectl
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
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

if [[ "$(free -h | grep -Po '(0B)' | tr '\n' ' ')" != "0B 0B 0B " ]]
then
    echo "Failed to disable swap"
    exit 1
fi

# Enable kernel modules
echo "Enabling kernel modules: overlay, br_netfilter"
sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Install Docker CE
sudo apt update

echo "Installing: gnupg2, software-properties-common, ca-certificates"
sudo apt install -y gnupg2 software-properties-common ca-certificates
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker-archive-keyring.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update

echo "Installing: containerd.io, docker-ce, docker-ce-cli"
sudo apt install -y containerd.io docker-ce docker-ce-cli

sudo mkdir -p /etc/systemd/system/docker.service.d

sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Restart and enable docker
echo "Restarting and enabling docker"
sudo systemctl daemon-reload 
sudo systemctl restart docker
sudo systemctl enable docker

#Check if docker is running
if [[ "$(sudo systemctl is-active docker)" != "active" ]]
then
    echo "Docker is not running - Make sure docker is running"
    exit 1
fi

# Install cri-dockerd
echo "Getting latest cri-dockerd version"
_DOCKERD_VER=$(curl -s https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest|grep tag_name | cut -d '"' -f 4|sed 's/v//g')
echo "Donwloaded cri-dockerd version: $_DOCKERD_VER"

wget https://github.com/Mirantis/cri-dockerd/releases/download/v${_DOCKERD_VER}/cri-dockerd-${_DOCKERD_VER}.amd64.tgz
tar -xvf cri-dockerd-${_DOCKERD_VER}.amd64.tgz

sudo mv cri-dockerd/cri-dockerd /usr/local/bin/

if [[ "$(cri-dockerd --version | grep -Po '(?<=cri-dockerd )[^ ]+')" == "" ]]
then
    echo "Failed to install cri-dockerd"
    exit 1
fi

# Configure cri-dockerd
wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service
wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket
sudo mv cri-docker.socket cri-docker.service /etc/systemd/system/
sudo sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service

# Restart and enable cri-dockerd
echo "Restarting and enabling cri-dockerd"
sudo systemctl daemon-reload
sudo systemctl enable cri-docker.service
sudo systemctl enable --now cri-docker.socket
sudo systemctl restart cri-docker.service

#Check if cri-dockerd is running
if [[ "$(sudo systemctl is-active cri-docker.service)" != "active" ]]
then
    echo "cri-dockerd is not running - Make sure cri-dockerd is running"
    exit 1
fi

# Check if br_netfilter is loaded before kubeadm
if [[ "$(lsmod | grep br_netfilter)" == "" ]]
then
    echo "br_netfilter is not loaded - Make sure br_netfilter is loaded"
    exit 1
fi

sudo systemctl enable kubelet

# Pull kubernetes images
echo "Pulling kubernetes images"
sudo kubeadm config images pull --cri-socket unix:///run/cri-dockerd.sock

# Initialize kubernetes
echo "Initializing kubernetes"
sudo sysctl -p
sudo kubeadm init \
  --pod-network-cidr=172.24.0.0/16 \
  --cri-socket unix:///run/cri-dockerd.sock 

echo -e "\n\n"
echo "Please read the above message from kubeadm init"
echo -e "\n\n"
echo "Kubernetes cluster initialized successfully"
echo -e "\n"
echo "Test it out by running:"
echo "  kubectl get pods --all-namespaces -w"
echo -e "\n"
echo "All thats left to do is to install a network plugin"
echo "Run the following script to install calico network plugin"
echo "  install_calico.sh"
echo "Dont forget to update pod cidr in 'install_calico.sh' if you changed it from the default"