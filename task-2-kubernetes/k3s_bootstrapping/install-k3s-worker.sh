#!/usr/bin/env bash
set -Eeuo pipefail

# Required variables:
# MASTER_IP
# WORKER_IP
# NODE_NAME
# FLANNEL_IFACE
# DISABLE_UFW=true|false
# RESET_EXISTING=true|false
# K3S_TOKEN

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
require_var "WORKER_IP"
require_var "NODE_NAME"
require_var "FLANNEL_IFACE"
require_var "DISABLE_UFW"
require_var "RESET_EXISTING"
require_var "K3S_TOKEN"

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
  echo "[5/8] Removing existing k3s-agent installation..."
  /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || true
  ip link delete cni0 2>/dev/null || true
  ip link delete flannel.1 2>/dev/null || true
else
  echo "[5/8] Skipping reset."
fi

echo "[6/8] Testing connection to master..."
if ! curl -k --connect-timeout 5 "https://${MASTER_IP}:6443/ping" >/dev/null 2>&1; then
  echo "WARNING: cannot reach https://${MASTER_IP}:6443/ping yet." >&2
  echo "WARNING: check firewall, private networking, or master status." >&2
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
