#!/usr/bin/env bash
set -Eeuo pipefail

# Required variables:
# MASTER_IP
# NODE_NAME
# FLANNEL_IFACE
# DISABLE_UFW=true|false
# RESET_EXISTING=true|false

require_var() {
  local var_name="$1"

  if [[ -z "${!var_name:-}" ]]; then
    echo "ERROR: $var_name is required." >&2
    exit 1
  fi
}

require_bool() {
  local var_name="$1"
  local value="${!var_name}"

  if [[ "$value" != "true" && "$value" != "false" ]]; then
    echo "ERROR: $var_name must be true or false." >&2
    exit 1
  fi
}

require_var "MASTER_IP"
require_var "NODE_NAME"
require_var "FLANNEL_IFACE"
require_var "DISABLE_UFW"
require_var "RESET_EXISTING"

require_bool "DISABLE_UFW"
require_bool "RESET_EXISTING"

if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: please run as root." >&2
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
  echo "[5/8] Skipping reset."
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
echo "MASTER_IP=${MASTER_IP}"
echo "K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)"
