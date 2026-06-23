#!/usr/bin/env bash
set -Eeuo pipefail

MASTER_IP="${MASTER_IP:-10.116.0.2}"
WORKER_IP="${WORKER_IP:-10.116.0.3}"
NODE_NAME="${NODE_NAME:-k3s-worker-1}"
FLANNEL_IFACE="${FLANNEL_IFACE:-eth1}"
DISABLE_UFW="${DISABLE_UFW:-true}"
RESET_EXISTING="${RESET_EXISTING:-false}"

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root."
  exit 1
fi

if [[ -z "${K3S_TOKEN:-}" ]]; then
  echo "K3S_TOKEN is required."
  echo
  echo "Get it from the master:"
  echo "cat /var/lib/rancher/k3s/server/node-token"
  echo
  echo "Then run:"
  echo "K3S_TOKEN='TOKEN_HERE' ./install-k3s-worker.sh"
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
  echo "[5/8] Removing existing k3s-agent installation..."
  /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
  ip link delete cni0 2>/dev/null || true
  ip link delete flannel.1 2>/dev/null || true
else
  echo "[5/8] Skipping reset. Set RESET_EXISTING=true to reinstall."
fi

echo "[6/8] Testing connection to master..."
if ! curl -k --connect-timeout 5 "https://${MASTER_IP}:6443/ping" >/dev/null 2>&1; then
  echo "Warning: cannot reach https://${MASTER_IP}:6443/ping yet."
  echo "Check firewall, private networking, or master status."
fi

if systemctl is-active --quiet k3s-agent 2>/dev/null; then
  echo "k3s-agent is already running. Skipping install."
else
  echo "[7/8] Installing k3s worker..."
  curl -sfL https://get.k3s.io | \
    K3S_URL="https://${MASTER_IP}:6443" \
    K3S_TOKEN="${K3S_TOKEN}" \
    INSTALL_K3S_EXEC="agent \
      --node-name ${NODE_NAME} \
      --node-ip ${WORKER_IP} \
      --flannel-iface ${FLANNEL_IFACE}" sh -
fi

echo "[8/8] Worker service status..."
systemctl status k3s-agent --no-pager

echo
echo "K3s worker install completed."
echo "Check nodes from the master:"
echo "kubectl get nodes -o wide"
