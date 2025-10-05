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

Write-Log "PowerShell setup completed"
