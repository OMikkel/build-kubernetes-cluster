# build-kubernetes-cluster
A set of scripts to initialise a new standard kubernetes cluster running the latest version

### :warning: Warning
This only works with ubuntu at the moment

## Get Started

Run the following commands to download the init kubernetes script
```console
curl -O https://raw.githubusercontent.com/OMikkel/build-kubernetes-cluster/master/install_kubernetes.sh
sudo chmod +x ./install_kubernetes.sh
./install_kubernetes.sh
```

If you wish to install the calico network plugin. Run the following commands
```console
curl -O https://raw.githubusercontent.com/OMikkel/build-kubernetes-cluster/master/install_calico.sh
sudo chmod +x ./install_calico.sh
./install_calico.sh
```
