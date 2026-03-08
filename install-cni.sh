#!/bin/bash

echo "Starting installation of Calico network plugin for Kubernetes"

# Installerer Custom Resource Definitions (CRDs)
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/operator-crds.yaml

# Installerer selve Tigera Operatoren
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/tigera-operator.yaml

# Download Calico Network Plugin
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/custom-resources.yaml

# Opdaterer CIDR for pod netværket i custom-resources.yaml
if [[ ! -f custom-resources.yaml ]]
then
    echo "Failed to download custom-resources.yaml"
    exit 1
fi

if [[ -z "$CLUSTER_CIDR" ]]
then
    echo "No CIDR provided, using default:"
    read -p "Enter the desired CIDR for the pod network (default: 192.168.0.0/16): " CLUSTER_CIDR
fi
CLUSTER_CIDR=${CLUSTER_CIDR:-192.168.0.0/16}
sed -i "s/192.168.0.0/$(echo $CLUSTER_CIDR | cut -d'/' -f1)/" custom-resources.yaml
sed -i "s/16/$(echo $CLUSTER_CIDR | cut -d'/' -f2)/" custom-resources.yaml

# Installerer Calico Network Plugin
kubectl create -f custom-resources.yaml

echo -e "\n\n"
echo "Calico installed successfully"
echo "Run 'watch kubectl get tigerastatus' to check the status of the installation"

