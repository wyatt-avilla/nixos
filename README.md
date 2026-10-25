# NixOS Configuration

My NixOS system configuration. My Home Manager configuration is
[here](https://github.com/wyatt-avilla/home-manager).

## Hosts

This configuration defines 4 hosts.

1. [desktop](https://github.com/wyatt-avilla/nixos/tree/main/hosts/desktop)
2. [laptop](https://github.com/wyatt-avilla/nixos/tree/main/hosts/laptop)
3. [homelab](https://github.com/wyatt-avilla/nixos/tree/main/hosts/homelab)
4. [vps](https://github.com/wyatt-avilla/nixos/tree/main/hosts/vps)

The VPS is a small Digital Ocean droplet, a configurable custom ISO can be built with:

```sh
nix run .#build-vps-image
```

## Server notifications

The homelab (`barachiel`) and VPS (`ambriel`) enable
`services.homelabObservability`, which configures Prometheus, Alertmanager, and
[attosend](https://github.com/wyatt-avilla/attosend). Attosend delivers through
Resend, checks the other host's WireGuard address and local monitoring readiness,
and reports failed systemd units independently of Prometheus.

Notification settings are under `services.attosend`; the former
`services.homelabNotifications` options and `homelab-notify` command are removed.
The shared module supplies the existing sender, recipient, and SOPS credential
path. Only the daemon receives the Resend key through systemd `LoadCredential`;
secret rotation restarts `attosend.service`.

```sh
sudo attosend queue
sudo attosend retry MESSAGE_UUID
sudo attosend check
sudo attosend submit --key maintenance:test --summary "TEST: notification check"
sudo attosend submit --key maintenance:test --status resolved --summary "TEST: notification check recovered"
journalctl -u attosend -u attosend-check
systemctl status attosend.service attosend-check.timer
```

The HTTP webhook and metrics listener remains on `127.0.0.1:9169`. Administration
uses `/run/attosend/control.sock`, accessible to root and the `attosend` group.
Group membership grants queue access and notification submission. State lives in
`/var/lib/attosend/queue.db`; never open the live database with another database
client.

Commands require the daemon to be running. Committed messages survive restarts,
but new submissions fail during daemon downtime. Polling discovers units still
failed after restart; a failure that occurs and clears entirely during downtime
can be missed. Checks run every 30 seconds, peer/readiness outages require 120
seconds of observed failure, and recovery requires two healthy samples. Reminders
remain six hours apart.

### Python migration and rollout

This migration starts a fresh attosend database. It does not import or drain the
Python queue. `/var/lib/homelab-notifications/queue.sqlite` and its companion files
are left untouched for reference and rollback; outstanding messages there are
not delivered by attosend. Existing incidents can produce fresh firing emails,
and resolutions for incidents unknown to the new database are ignored.

Before merging, require all Nix CI checks and all four host builds to pass. Record
`readlink -f /run/current-system` and notification status on each server. The
existing main-branch deployment workflow builds both server closures, activates
the VPS first, then the homelab. It does not pause for notification verification
between hosts; inspect the deployment status and verify both hosts afterward.

On each server:

1. Confirm `attosend.service` and `attosend-check.timer` are active, and
   `sudo attosend queue` succeeds. Check the generated configuration's peer and
   readiness endpoints without reading the credential contents.
2. Confirm the old `homelab-notifications.service`, `notification-check.service`,
   `notification-check.timer`, and `notification-failure@.service` are absent.
   Check that unit `OnFailure` properties reference only `attosend-failure@`.
3. Check `curl -fsS http://127.0.0.1:9169/metrics`, the local Prometheus target
   health, and loopback-only listening. Watch the journal for delivery errors and
   verify the queue drains through several checker cycles.
4. Send clearly labeled test firing/recovery events through the CLI and
   Alertmanager, then verify their deliveries. Use a temporary failing systemd
   unit to verify failure and recovery notifications; clear its failed state and
   remove the unit afterward. Do not interrupt real applications or WireGuard.

If verification fails, stop attosend and restore the recorded system generation
on each affected host using the existing deployment activation mechanism (the
VPS provides `deploy-vps-activate`). Restore both the system profile and running
configuration. Preserve both state directories, and revert the migration in Git
so future automatic deployments retain the rollback. Python may resume sending
its outstanding queue when restored; do not copy the attosend database over it.
