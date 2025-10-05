# SNMPD container bootstrap for Azure Ubuntu VM


This small helper contains `start.sh` — an idempotent bootstrap script for an Ubuntu VM.

## What it does

- Ensures required apt packages are installed (git, curl, etc.)
- Installs Docker Engine if missing
- Clones (or updates) the project repository
- Builds the image and runs a container exposing UDP ports 161 and 162

Additionally, the script will pull and run a MIBs cache HTTP(S) service:

- Image: `ghcr.io/lextudio/mibs.pysnmp.com:cache`
- Exposes TCP ports 80 and 443 on the host

The project repository used by the script is: [lextudio/docker-snmpd-sharpsnmp](https://github.com/lextudio/docker-snmpd-sharpsnmp)

## How to run

1. Copy the files to your Ubuntu VM (or clone this repo into /opt/ or your home directory).
2. Make the script executable and run it as root:

```bash
chmod +x start.sh
sudo ./start.sh
```


## Azure notes

- Azure VMs are protected by Network Security Groups (NSGs). Open inbound UDP ports 161 (SNMP) and 162 (SNMP traps) on the VM's NSG to allow SNMP traffic. Also ensure any Azure Firewall or other network appliances allow the traffic.

- If you use the optional MIBs cache, open inbound TCP ports 80 and 443 as well.

### Automatic updates and reboots

If you enable Azure automatic OS updates, the VM may reboot automatically. To ensure your Docker containers come back after a reboot, the scripts run containers with a restart policy of `--restart unless-stopped`. This ensures Docker restarts the containers on daemon startup or host reboot.

If you prefer stronger guarantees you can:

- Use `--restart always` (same effect for auto-start, but `unless-stopped` avoids restarting when you intentionally stop a container).
- Use a small systemd unit that depends on `docker.service` to start specific containers via `docker start <name>` after Docker is up.


## Security

- The script uses Docker's official apt repository. Review the script before running on production systems.

## Troubleshooting

- If Docker install fails due to missing apt keys or network rules, run the steps in the Docker install docs manually.
- If the container doesn't bind to port 161, check that no host service is already using that port and that the container started successfully: `sudo docker ps -a`.
