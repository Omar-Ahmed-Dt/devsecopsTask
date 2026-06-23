#!/usr/bin/env bash
set -Eeuo pipefail

MASTER_IP="${MASTER_IP:-10.116.0.2}"
NODE_NAME="${NODE_NAME:-k3s-master}"
FLANNEL_IFACE="${FLANNEL_IFACE:-eth1}"
DISABLE_UFW="${DISABLE_UFW:-true}"
RESET_EXISTING="${RESET_EXISTING:-false}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root."
  exit 1
fi

echo "[1/8] Installing prerequisites..."
apt update
apt install -y curl ca-certificates iptables

echo "[2/8] Setting hostname to ${NODE_NAME}..."
hostnamectl set-hostname "${NODE_NAME}"

echo "[3/8] Disabling swap..."
swapoff -a || true
sed -i.bak '/ swap / s/^/#/' /etc/fstab || true

if [[ "${DISABLE_UFW}" == "true" ]]; then
  echo "[4/8] Disabling UFW..."
  systemctl stop ufw 2>/dev/null || true
  systemctl disable ufw 2>/dev/null || true
else
  echo "[4/8] Leaving UFW unchanged..."
fi

if [[ "${RESET_EXISTING}" == "true" ]]; then
  echo "[5/8] Removing existing k3s installation..."
  /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
  ip link delete cni0 2>/dev/null || true
  ip link delete flannel.1 2>/dev/null || true
else
  echo "[5/8] Skipping reset. Set RESET_EXISTING=true to reinstall."
fi

if systemctl is-active --quiet k3s 2>/dev/null; then
  echo "k3s is already running. Skipping install."
else
  echo "[6/8] Installing k3s server..."
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --node-name ${NODE_NAME} \
    --node-ip ${MASTER_IP} \
    --advertise-address ${MASTER_IP} \
    --tls-san ${MASTER_IP} \
    --flannel-iface ${FLANNEL_IFACE}" sh -
fi

echo "[7/8] Preparing kubeconfig..."
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
sed -i "s/127.0.0.1/${MASTER_IP}/g" /root/.kube/config
sed -i "s/localhost/${MASTER_IP}/g" /root/.kube/config
chmod 600 /root/.kube/config

echo "[8/8] Cluster status..."
export KUBECONFIG=/root/.kube/config
kubectl get nodes -o wide

echo
echo "K3s master installed successfully."
echo
echo "Worker join token:"
cat /var/lib/rancher/k3s/server/node-token
echo
echo "Use this on the worker:"
echo "MASTER_IP=${MASTER_IP} K3S_TOKEN=\"$(cat /var/lib/rancher/k3s/server/node-token)\" bash install-k3s-worker.sh"
