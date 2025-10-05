#!/usr/bin/env pwsh
<# start.ps1
Pulls prebuilt GHCR images and runs containers for SNMP (UDP 161/162) and MIBs cache (TCP 80/443).
This script replaces the previous start.sh and is intended to be idempotent.
#>

[CmdletBinding()]
param(
  [string]$InstallDir = $(Get-Location).Path
)

function Write-Log { param($m) Write-Output "$(Get-Date -Format u) $m" }

# Ensure we are running as root. The wrapper should invoke this script as root.
$isRoot = $false
try { $uid = (& id -u 2>$null) ; if ($uid -eq '0') { $isRoot = $true } } catch {}
if (-not $isRoot) {
  Write-Error "start.ps1 must be run as root. Please run via sudo or as root."
  exit 2
}

Write-Log "Starting start.ps1 in $InstallDir"

Write-Log "Checking Docker availability"
try {
  $dv = & docker version --format '{{.Server.Version}}' 2>&1
  Write-Log "Docker server version: $dv"
} catch {
  Write-Error "Docker does not appear to be available or running: $_"
  exit 3
}

$snmpImage = 'ghcr.io/lextudio/docker-snmpd-sharpsnmp:main'
$snmpContainer = 'snmpd-sharpsnmp'

$mibsImage = 'ghcr.io/lextudio/mibs.pysnmp.com:cache'
$mibsContainer = 'mibs-cache'

function Start-ContainerFromImage {
  param(
    [Parameter(Mandatory=$true)][string]$Image,
    [Parameter(Mandatory=$true)][string]$ContainerName,
    [Parameter(Mandatory=$true)][string[]]$Ports
  )

  Write-Log "Pulling image $Image"
  try {
    # Stream docker pull output so progress is visible in SSH session
    & docker pull $Image 2>&1 | ForEach-Object { Write-Log $_ }
  } catch {
    Write-Error "docker pull failed for $($Image): $($_.Exception.Message)"
    throw
  }

  Write-Log "Checking for existing container named $ContainerName"
  $existing = docker ps -a --format '{{.Names}}' | Select-String -SimpleMatch $ContainerName
  if ($existing) {
    Write-Log "Removing existing container $ContainerName"
  try { & docker rm -f $ContainerName 2>&1 | ForEach-Object { Write-Log $_ } } catch { Write-Error "docker rm failed: $($_.Exception.Message)"; throw }
  }

  $args = @('run','-d','--name',$ContainerName,'--restart','unless-stopped')
  foreach ($p in $Ports) { $args += '-p'; $args += $p }
  $args += $Image

  Write-Log "Running container $ContainerName (docker ${args -join ' '})"
  try {
    & docker @args 2>&1 | ForEach-Object { Write-Log $_ }
  } catch {
    Write-Error "docker run failed for $($ContainerName): $($_.Exception.Message)"
    throw
  }
}

Start-ContainerFromImage -Image $snmpImage -ContainerName $snmpContainer -Ports @('161:161/udp','162:162/udp')
Start-ContainerFromImage -Image $mibsImage -ContainerName $mibsContainer -Ports @('80:80/tcp','443:443/tcp')

Write-Log "start.ps1 finished"
