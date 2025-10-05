#!/usr/bin/env pwsh
<#
setup.ps1
PowerShell one-time setup for Ubuntu VM. Run as root (the wrapper setup.sh will do this).

Usage: pwsh -NoProfile -File ./setup.ps1 /path/to/install-dir
#>

param(
  [Parameter(Mandatory=$true)]
  [string]$InstallDir
)

function Write-Log {
  param($msg)
  $ts = (Get-Date).ToString("u")
  Write-Output "$ts $msg"
}

Write-Log "Starting PowerShell setup in $InstallDir"

if (-not (Test-Path $InstallDir)) {
  Write-Log "Install directory $InstallDir does not exist. Exiting."
  exit 1
}

# Ensure we're running as root (setup.sh calls pwsh with sudo). Fail early if not.
$isRoot = $false
try { $uid = (& id -u 2>$null) ; if ($uid -eq '0') { $isRoot = $true } } catch {}
if (-not $isRoot) { Write-Log "setup.ps1 must be run as root"; exit 1 }

# Ensure apt packages
Write-Log "Ensuring apt packages: ca-certificates curl gnupg lsb-release git"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release git

# Ensure Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Log "Installing Docker using official instructions"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $arch = dpkg --print-architecture
  $codename = lsb_release -cs
  $entry = "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable"
  $entry | sudo tee /etc/apt/sources.list.d/docker.list > $null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker || Write-Log "Warning: could not enable/start docker service"
} else {
  Write-Log "Docker found at $(Get-Command docker). Skipping install."
}

Write-Log "Invoking start.ps1 to pull images and run containers"
if (Test-Path "$InstallDir/start.ps1") {
  sudo pwsh -NoProfile -ExecutionPolicy Bypass -File "$InstallDir/start.ps1" "$InstallDir"
} else {
  Write-Log "start.ps1 not found in $InstallDir; skipping"
}

Write-Log "Pruning unused Docker images"
sudo docker image prune -af || Write-Log "docker prune failed"

Write-Log "Ensuring firewall (ufw) allows needed ports"
try {
  if (-not (Get-Command ufw -ErrorAction SilentlyContinue)) {
    Write-Log "Installing ufw"
    sudo apt-get install -y ufw
  }

  # Allow SSH first to avoid lockout
  Write-Log "Allowing OpenSSH to prevent lockout"
  ufw allow OpenSSH || Write-Log "ufw allow OpenSSH failed"

  Write-Log "Allowing TCP ports 80 and 443"
  ufw allow 80/tcp || Write-Log "ufw allow 80/tcp failed"
  ufw allow 443/tcp || Write-Log "ufw allow 443/tcp failed"

  Write-Log "Allowing UDP ports 161 and 162"
  ufw allow 161/udp || Write-Log "ufw allow 161/udp failed"
  ufw allow 162/udp || Write-Log "ufw allow 162/udp failed"

  Write-Log "Enabling ufw (non-interactive)"
  ufw --force enable || Write-Log "ufw enable failed"
} catch {
  Write-Log "Firewall configuration failed: $($_.Exception.Message)"
}

Write-Log "PowerShell setup completed"
