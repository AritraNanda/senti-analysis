# OpenNebula Lab: 2 App Nodes + 1 Load Balancer (end‑to‑end)

This lab gets you from “Sunstone is up” to a working demo cloud managed by OpenNebula that serves a tiny web/AI app behind a load balancer, with simple performance measurements you can report (latency, throughput, jitter). It’s designed for your environment: OpenNebula running inside a Linux VM on a Windows host.

You get two tracks:
- Track A (RECOMMENDED here): OpenNebula + LXD instances — no nested KVM required; works reliably in VirtualBox.
- Track B (Optional): OpenNebula + KVM VMs — only if you move OpenNebula to bare‑metal Linux or a hypervisor with reliable nested virtualization.

---

## 0. Prerequisites and assumptions
- You can open Sunstone at `http://<opennebula_vm_ip>:9869` (or via VirtualBox NAT port‑forward).
- Linux VM has Internet access.
- You can run commands with sudo inside the OpenNebula VM.
- SSH public key available to inject into instances (we’ll generate one below if needed).

Glossary: In this document, “host VM” = the Linux VM where OpenNebula runs.

---

## Track A — OpenNebula + LXD (recommended for VirtualBox on Windows)

Why: LXD instances don’t need hardware virtualization, so they run fine inside VirtualBox. You still manage everything via OpenNebula (Sunstone/CLI).

### A1) Prepare host for LXD (run inside the OpenNebula VM)
```bash
# Install and initialize LXD
sudo snap install lxd
sudo lxd init            # accept defaults; choose dir storage unless you want ZFS

# Allow oneadmin to use LXD
sudo usermod -aG lxd oneadmin
sudo -u oneadmin newgrp lxd   # or log out/in

# Register this host in OpenNebula using LXD drivers
sudo -u oneadmin onehost create $(hostname) -i lxd -v lxd

# Confirm it reaches MONITORED state (may take ~1 min)
sudo -u oneadmin onehost list
```

### A2) Create a virtual network and base image (Sunstone UI)
- Network > Virtual Networks > Create
  - Name: `vnet-lxd`
  - Address range: `10.20.0.0/24` (or use AR wizard)
  - Bridge: leave default (LXD creates `lxdbr0`)
- Templates > Images > + Create
  - Type: OS
  - Datastore: LXD image datastore
  - Path/Name: `ubuntu:22.04` (LXD image alias)
  - Save

### A3) Create App template (LXD) with cloud‑init (no Docker)
In Sunstone: Templates > VM Templates > + Create
- Type/Hypervisor: LXD
- OS/IMAGE: `ubuntu:22.04`
- Network: attach `vnet-lxd`
- Context > Cloud‑Init > paste the user‑data below
- Add variables (Context tab):
  - `MONGODB_URL` (optional)
  - `DATABASE_NAME=sentiment`
  - `ML_MODEL_URL=http://127.0.0.1:8001/analyze`
- Save as `tpl-app`

User‑data (copy/paste):
```yaml
#cloud-config
package_update: true
packages:
  - git
  - ca-certificates
  - curl
  - python3
  - python3-pip
  - python3-venv
write_files:
  - path: /etc/default/senti
    permissions: '0644'
    content: |
      MONGODB_URL="${MONGODB_URL:-}"
      DATABASE_NAME="${DATABASE_NAME:-sentiment}"
      ML_MODEL_URL="${ML_MODEL_URL:-http://127.0.0.1:8001/analyze}"
  - path: /etc/systemd/system/sa-ml.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Senti ML Model Service
      After=network.target

      [Service]
      Type=simple
      User=ubuntu
      WorkingDirectory=/opt/senti/ml-model
      ExecStart=/opt/senti/ml-model/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8001
      Restart=always
      RestartSec=3

      [Install]
      WantedBy=multi-user.target
  - path: /etc/systemd/system/sa-api.service
    permissions: '0644'
    content: |
      [Unit]
      Description=Senti API Service
      After=network.target

      [Service]
      Type=simple
      User=ubuntu
      WorkingDirectory=/opt/senti/api
      EnvironmentFile=/etc/default/senti
      ExecStart=/opt/senti/api/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
      Restart=always
      RestartSec=3

      [Install]
      WantedBy=multi-user.target
runcmd:
  - |
    set -eux
    # Fetch source
    if [ ! -d /opt/senti ]; then
      git clone https://github.com/AritraNanda/senti-analysis.git /opt/senti || true
      chown -R ubuntu:ubuntu /opt/senti
    fi
  - |
    # ML service venv and deps
    cd /opt/senti/ml-model
    python3 -m venv .venv
    /opt/senti/ml-model/.venv/bin/pip install --upgrade pip
    /opt/senti/ml-model/.venv/bin/pip install -r requirements.txt
  - |
    # API service venv and deps
    cd /opt/senti/api
    python3 -m venv .venv
    /opt/senti/api/.venv/bin/pip install --upgrade pip
    /opt/senti/api/.venv/bin/pip install -r requirements.txt
  - |
    # Enable and start services
    systemctl daemon-reload
    systemctl enable --now sa-ml.service
    # API depends on ML; slight delay to let ML start first
    sleep 5 || true
    systemctl enable --now sa-api.service
```

Note: First run can take a while as the ML model downloads Python packages and models; subsequent runs are faster.

### A4) Launch two App instances
- Instantiate `tpl-app` twice → `app-1`, `app-2`.
- Wait until RUNNING; note their IPs in `vnet-lxd` (e.g., `10.20.0.11`, `10.20.0.12`).
- Quick checks from host VM:
```bash
curl -I http://10.20.0.11:8000 || true
curl -I http://10.20.0.12:8000 || true
```

### A5) Create LB template (LXD) with cloud‑init
In Sunstone: Templates > VM Templates > + Create
- Type/Hypervisor: LXD
- OS/IMAGE: `ubuntu:22.04`
- Network: `vnet-lxd`
- Context > Cloud‑Init > paste user‑data below
- Add variables: `APP1_IP`, `APP2_IP` (fill at instantiate time)
- Save as `tpl-lb`

User‑data (copy/paste):
```yaml
#cloud-config
package_update: true
packages:
  - haproxy
runcmd:
  - |
    set -eux
    cat >/etc/haproxy/haproxy.cfg <<'CFG'
    global
      log /dev/log    local0
      log /dev/log    local1 notice
      maxconn 4096
      daemon

    defaults
      log     global
      mode    http
      option  httplog
      option  dontlognull
      timeout connect 5s
      timeout client  30s
      timeout server  30s

    frontend http_in
      bind *:80
      default_backend api_backends

    backend api_backends
      balance roundrobin
      option httpchk GET /docs
      http-response set-header X-Served-By %[srv_name]
      server app1 ${APP1_IP}:8000 check
      server app2 ${APP2_IP}:8000 check
CFG
    systemctl enable --now haproxy
```

### A6) Launch LB and verify inside the VNET
- Instantiate `tpl-lb` with variables: `APP1_IP=10.20.0.11`, `APP2_IP=10.20.0.12`.
- Note the LB IP (e.g., `10.20.0.13`).
- From host VM:
```bash
for i in {1..5}; do curl -sI http://10.20.0.13/ | grep -i X-Served-By; sleep 1; done
```
Expect alternating `X-Served-By` headers.

### A7) Expose the LB to your Windows browser
- On the host VM, add an LXD proxy device mapping host‑VM port → LB container 80:
```bash
# Find the LB instance name created by OpenNebula
sudo lxc list
# Suppose it is one-<id> …
sudo lxc config device add <lb-instance-name> webproxy proxy \
  listen=tcp:0.0.0.0:30080 connect=tcp:127.0.0.1:80
```
- In VirtualBox (Windows): Settings > Network > Adapter 1 (NAT) > Advanced > Port Forwarding
  - Name: `sa-lb`
  - Protocol: TCP
  - Host IP: 127.0.0.1
  - Host Port: 8080
  - Guest IP: (leave blank)
  - Guest Port: 30080
- Open in Windows: `http://localhost:8080`

### A8) Measure performance
- Quick curl loop to see distribution:
```bash
for i in {1..10}; do curl -sI http://localhost:8080/api/docs | findstr /R /C:"X-Served-By" & timeout /t 1 >nul; done
```
- ApacheBench (inside host VM):
```bash
sudo apt update && sudo apt install -y apache2-utils
ab -n 1000 -c 50 http://localhost:8080/
```
Capture:
- Requests/sec (throughput)
- Time per request, and the percentiles table (p50/p90/p95/p99)
- Error rate (should be ~0)
- Jitter: discuss variability between percentiles

---

## Track B — OpenNebula + KVM (only if nested virtualization is available)

Use this if you run OpenNebula on bare‑metal Linux or on a hypervisor that exposes VT‑x/AMD‑V reliably to the guest. On VirtualBox/Windows this is often unreliable.

Quick outline:
1. Ensure KVM works on the host running OpenNebula:
```bash
egrep -c '(vmx|svm)' /proc/cpuinfo   # >0 means CPU supports virtualization
lsmod | grep kvm                     # kvm & kvm_intel/amd loaded
[ -e /dev/kvm ] && echo OK || echo NO
```
2. Install compute stack and register host:
```bash
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients
sudo usermod -aG libvirt oneadmin
sudo -u oneadmin onehost create $(hostname) -i kvm -v kvm
```
3. Use the same cloud‑init ideas (Flask app on app nodes; Nginx/HAProxy LB). Networking will be via OpenNebula VNets.

If `/dev/kvm` is missing or OpenNebula cannot deploy KVM guests, pick Track A.

---

## SLOs and what to report
- Response time: p95 < 2s
- Latency: average < 500ms for the simple endpoints
- Throughput: Requests/sec under `ab -n 1000 -c 50`
- Jitter: comment on p90→p95→p99 spread and `ping` variability

Optional extra:
```bash
ping -c 20 localhost   # from Windows to localhost:8080 won’t ICMP, but you can ping the host VM IP
```

---

## Troubleshooting cheat‑sheet
- Sunstone opens but instances fail: check host added with `-i lxd -v lxd` and reaches MONITORED.
- LB returns 502: ensure both app ports 8000 are open and containers are running; check `sudo lxc exec <app> -- docker logs sa-api`.
- Can’t reach from Windows: recheck LXD proxy (30080) and VirtualBox NAT forwarding (8080→30080); ensure Sunstone/lb not bound to 127.0.0.1 only.
- Slow build on first run: Docker image builds pull Python deps; subsequent runs are faster.

---

## Clean up
In Sunstone: delete the instances (`lb-1`, `app-1`, `app-2`). Optionally keep the templates for future runs.

---

This lab keeps everything “under OpenNebula” while remaining practical in a Windows+VirtualBox setup. If you later migrate OpenNebula to bare‑metal, you can switch the templates from LXD to KVM with the same cloud‑init logic.
