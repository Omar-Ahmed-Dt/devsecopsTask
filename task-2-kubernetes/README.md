# This task uses a self-managed K3s cluster with:
- One control-plane node
- One worker node
- Kubernetes API access through an SSH tunnel
- No public direct access to the Kubernetes API server

## Install K3s on the master node:
```sh
# Get a private ip
ip add show

MASTER_IP="<Master Node Private IP>" \
    NODE_NAME="k3s-master" \
    FLANNEL_IFACE="<Interface>" \
    DISABLE_UFW="true" \
    RESET_EXISTING="false" \
    ./k3s-server-install.sh

```

## Install K3s on the worker node:
```sh
# Get a private ip
ip add show

MASTER_IP="<Master Node Private IP>" \
    WORKER_IP="<Workder Noder Private IP>" \
    NODE_NAME="k3s-worker-1" \
    FLANNEL_IFACE="<Interface>" \
    DISABLE_UFW="true" \
    RESET_EXISTING="false" \
    K3S_TOKEN="<token>" \
    ./k3s-agent-install.sh

```

## Verify the cluster from the master node:
```sh
ssh -i ~/.ssh/<Private Key> <User>@<Public IP>
kubectl get nodes -o wide
```

## Configure local kubeconfig: 
```sh
mkdir -p ~/.kube/
scp <User>@<Public ip>:~/.kube/config ~/.kube/config
sed -i 's#server: https://10.116.0.2:6443#server: https://127.0.0.1:6443#' ~/.kube/config
```

## Access the Kubernetes API from local machine using SSH tunnel:
```sh
# Open an SSH tunnel from the local machine
ssh -N -L 6443:127.0.0.1:6443 root@<k3s-master-public-ip>
```

## Apply API-Access Restrictions:
```sh
# Allow from Master Node to API Server
sudo ufw allow from "<Private ip for Master Node>/32" to any port 6443 proto tcp
# Allow from LocalHost Using SSH Tunnel
sudo ufw allow from "<Public ip for Local Machine>/32" to any port 22 proto tcp
sudo ufw --force enable
sudo ufw status verbose
```

