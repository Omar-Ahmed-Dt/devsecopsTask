# This task uses a self-managed K3s cluster with:
- One control-plane node
- One worker node
- Kubernetes API access through an SSH tunnel
- No public direct access to the Kubernetes API server

## Install K3s on the master node:
```sh
cd task-2-kubernetes/k3s_bootstrapping/

sudo MASTER_IP="<master-private-ip>" \
    NODE_NAME="k3s-master" \
    FLANNEL_IFACE="eth1" \
    DISABLE_UFW="true" \ 
    RESET_EXISTING="false" \ 
    ./k3s-server-install.sh

```

## Install K3s on the worker node:
```sh
sudo MASTER_IP="<master-private-ip>" \
    WORKER_IP="<worker-private-ip>" \
    NODE_NAME="k3s-worker-1" \ 
    FLANNEL_IFACE="eth1" \ 
    DISABLE_UFW="true" \ 
    RESET_EXISTING="false" \ 
    K3S_TOKEN="<token-from-master>" \ 
    ./k3s-agent-install.sh

```

## Verify the cluster from the master node:
```sh
kubectl get nodes -o wide
```


## Access the Kubernetes API from local machine using SSH tunnel
```sh
ssh -N -L 6443:127.0.0.1:6443 root@<k3s-master-public-ip>
```

## Configure local kubeconfig
```sh
mkdir -p ~/.kube/
cp <From Master Node ~/.kube/config> <Localhost ~/.kube/config>
```

