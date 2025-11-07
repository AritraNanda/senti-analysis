# Conversation Log (AI Reference)

Purpose: Internal AI summary of user session progressing through OpenNebula + LXD setup and troubleshooting. Not intended for end-user documentation; captures rationale, decisions, blockers.

## Chronological Summary
1. User goal: Deploy sentiment analysis app (ML model + API) behind load balancer on OpenNebula using LXD; measure latency/throughput/jitter. Wants extremely small, beginner steps.
2. Verified Sunstone reachable (prerequisite complete).
3. Checked snap availability; installed LXD already (snap version reported 2.72). Proceeded to `lxd init` (storage chosen: dir). LXD bridge named `lxdbr1` because `lxdbr0` existed.
4. Added `oneadmin` to `lxd` group. Confirmed via `getent group lxd` output: `lxd:x:110:aritra,oneadmin`.
5. Attempted to add LXD host in Sunstone using hostname/IP. Host showed error state (monitoring failure). CLI `onehost list` displayed allocated mem stat: err.
6. Checked LXD daemon: active. Tested LXD access as oneadmin.
7. Encountered snap confinement error: oneadmin home under `/var/lib/one` blocked by snap policy ("home directories outside of /home needs configuration").
8. Attempted snap system settings (`home`, `homedirs`) – not available in current snap core revision.
9. Workaround strategy: Provide acceptable HOME for oneadmin under `/home/oneadmin` without moving OpenNebula data directory from `/var/lib/one`.
10. Direct home change with `usermod -d` failed (process in use). Decided on environment override approach for OpenNebula service.
11. Created `/home/oneadmin`, ownership & perms set. Plan: systemd override for OpenNebula to export `HOME=/home/oneadmin` so monitoring scripts calling `lxc` run inside allowed home path context.
12. Applied systemd override and restarted `opennebula` service. Pending confirmation whether host becomes MONITORED.

## Key Decisions & Rationale
- Track A (LXD) chosen: avoids nested virtualization complexity on VirtualBox.
- Use IP instead of hostname for host registration to bypass potential DNS issues.
- Snap confinement workaround chosen over altering oneadmin UID or relocating OpenNebula data (low-risk, minimally invasive).

## Commands Executed / Intended
- `sudo snap install lxd`
- `sudo lxd init` (dir storage; existing bridge forced creation of `lxdbr1`).
- `sudo usermod -aG lxd oneadmin`
- `sudo systemctl restart opennebula` (refresh after group add not picked up initially).
- Diagnostics: `sudo snap services lxd`, `sudo -u oneadmin lxc list`, `getent group lxd`, `sudo -u oneadmin onehost list`.
- Workaround: create `/home/oneadmin`, add systemd override: `/etc/systemd/system/opennebula.service.d/override.conf` with `Environment=HOME=/home/oneadmin`.

## Current State (Unresolved / To Confirm)
- Need confirmation that the LXD host now transitions to MONITORED after HOME override. If still ERROR:
  - Next diagnostics: `sudo -u oneadmin onehost show <ID> | sed -n '1,120p'`, inspect `/var/log/one/oned.log` tail.
  - Validate socket ACL: `getfacl /var/snap/lxd/common/lxd/unix.socket`.
  - Confirm `oneadmin` can run `sudo -u oneadmin env HOME=/home/oneadmin lxc version`.

## Next Planned Steps (After Host MONITORED)
1. Create VNet (`vnet-lxd` 10.20.0.0/24) in Sunstone.
2. Create Image referencing `ubuntu:22.04` LXD alias.
3. Create App template (`tpl-app`) with provided cloud-init user-data.
4. Instantiate two app containers; verify services on ports 8000 / 8001.
5. Create LB template (`tpl-lb`) with HAProxy cloud-init.
6. Instantiate LB with app IP variables; test round-robin via `X-Served-By` header.
7. Expose LB: LXD proxy device + VirtualBox NAT port forwarding.
8. Performance measurement: `ab -n 1000 -c 50 http://localhost:8080/` capture throughput & latency percentiles.
9. Document SLOs vs observed metrics.

## Potential Risks / Watchpoints
- Snap confinement may still interfere if systemd override not picked up (verify environment in process: `sudo systemctl show opennebula | grep Environment=`).
- Multiple LXD bridges could confuse networking; ensure OpenNebula chooses correct one (typically LXD driver enumerates default). If IP allocation fails, specify network manually in VM template.
- First app deployment slow due to Python dependency install—avoid interpreting initial latency as steady-state performance.

## Optional Future Enhancements
- Add Prometheus/Grafana from existing repo `prometheus.yml` & `grafana.yaml` under `k8s/monitoring` for time-series metrics.
- Introduce MongoDB (using existing YAML manifests) and set `MONGODB_URL` variable in template.
- Migrate to KVM track if nested virtualization becomes available.

## Reference Snippets (Cloud-Init User-Data)
(App template and LB template preserved in `opennebula/LAB_README.md`). Not duplicated here to reduce redundancy.

## End Note
This log is for AI internal continuity. User expects ultra-small incremental guidance, confirming each step before proceeding.
