#!/usr/bin/env bash
# Prepare the OpenNebula frontend/host for LXD workloads and register it with OpenNebula.
# Usage: sudo ./prepare-lxd-host.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[ERR] Please run as root or with sudo." >&2
  exit 1
fi

log() { echo "[prepare-lxd-host] $*"; }

# 1) Install LXD if missing
if ! command -v lxd >/dev/null 2>&1; then
  log "Installing LXD via snap…"
  if ! command -v snap >/dev/null 2>&1; then
    log "Installing snapd…"
    apt-get update -y
    apt-get install -y snapd
  fi
  snap install lxd
else
  log "LXD already installed."
fi

# 2) Initialize LXD (non-interactive by default)
INIT_MODE=${LXD_INIT_MODE:-auto}
if ! lxc network list >/dev/null 2>&1; then
  if [[ "$INIT_MODE" == "auto" ]]; then
    log "Running non-interactive lxd init --auto (dir storage, default lxdbr0)…"
    lxd init --auto
  else
    log "Launching interactive lxd init (answer prompts)…"
    lxd init
  fi
else
  log "LXD already initialized."
fi

# 3) Ensure oneadmin exists and is in lxd group
if id oneadmin >/dev/null 2>&1; then
  if id -nG oneadmin | grep -qw lxd; then
    log "oneadmin already in lxd group."
  else
    log "Adding oneadmin to lxd group…"
    usermod -aG lxd oneadmin
    log "oneadmin added to lxd group. You may need to log out/in for it to take effect."
  fi
else
  log "[WARN] user 'oneadmin' not found. Ensure OpenNebula is installed. Continuing…"
fi

# 4) Register this host in OpenNebula using LXD drivers (if OpenNebula CLI available)
if sudo -u oneadmin bash -lc 'command -v onehost' >/dev/null 2>&1; then
  HOSTNAME=$(hostname)
  if sudo -u oneadmin bash -lc "onehost list | awk '{print $2}' | grep -xq '$HOSTNAME'"; then
    log "Host '$HOSTNAME' already exists in OpenNebula."
  else
    log "Registering host '$HOSTNAME' with drivers -i lxd -v lxd …"
    sudo -u oneadmin bash -lc "onehost create '$HOSTNAME' -i lxd -v lxd"
  fi
  # 5) Wait briefly for MONITORED state
  log "Waiting for host to reach MONITORED state (up to 90s)…"
  SECS=0
  until sudo -u oneadmin bash -lc "onehost list | awk -v h='$HOSTNAME' '$2==h {print $5}'" | grep -Eq 'MONITORED|ON'; do
    sleep 5
    SECS=$((SECS+5))
    if (( SECS >= 90 )); then
      log "[WARN] Host not MONITORED yet. Current onehost list:"; sudo -u oneadmin bash -lc 'onehost list' || true
      break
    fi
  done
  log "Done. Current host status:"; sudo -u oneadmin bash -lc 'onehost list' || true
else
  log "[INFO] OpenNebula CLI (onehost) not found for user oneadmin. Skipping host registration."
fi

log "Preparation complete. If you just added oneadmin to the lxd group, re-login to apply group membership."
