# Install Calico
echo "Installing Calico"
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml 

sed -ie 's/192.168.0.0/172.24.0.0/g' custom-resources.yaml

kubectl create -f tigera-operator.yaml
kubectl create -f custom-resources.yaml



echo -e "\n\n"
echo "Calico installed successfully"
echo "Run 'kubectl get pods --all-namespaces -w' to check the status of the pods"
echo "If you wish to schedule pods on the control-plane, run the following commands:"
echo "  kubectl taint nodes --all node-role.kubernetes.io/master-"
echo "  kubectl taint nodes --all  node-role.kubernetes.io/control-plane-"