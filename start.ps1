#!/usr/bin/env pwsh
<# start.ps1
Pulls prebuilt GHCR images and runs containers for SNMP (UDP 161/162) and MIBs cache (TCP 80/443).
This script replaces the previous start.sh and is intended to be idempotent.
#>

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

$snmpImage = 'ghcr.io/lextudio/docker-snmpd-sharpsnmp:main'
$snmpContainer = 'snmpd-sharpsnmp'

$mibsImage = 'ghcr.io/lextudio/mibs.pysnmp.com:cache'
$mibsContainer = 'mibs-cache'

[CmdletBinding(SupportsShouldProcess=$true)]
param()

function Start-ContainerFromImage {
  param(
    [Parameter(Mandatory=$true)][string]$Image,
    [Parameter(Mandatory=$true)][string]$ContainerName,
    [Parameter(Mandatory=$true)][string[]]$Ports
  )

  Write-Log "Pulling image $Image"
  & docker pull $Image | Out-Null

  $existing = docker ps -a --format '{{.Names}}' | Select-String -SimpleMatch $ContainerName
  if ($existing) {
    Write-Log "Removing existing container $ContainerName"
    & docker rm -f $ContainerName | Out-Null
  }

  $args = @('run','-d','--name',$ContainerName,'--restart','unless-stopped')
  foreach ($p in $Ports) { $args += '-p'; $args += $p }
  $args += $Image

  Write-Log "Running container $ContainerName"
  & docker @args | Out-Null
}

Start-ContainerFromImage -Image $snmpImage -ContainerName $snmpContainer -Ports @('161:161/udp','162:162/udp')
Start-ContainerFromImage -Image $mibsImage -ContainerName $mibsContainer -Ports @('80:80/tcp','443:443/tcp')

Write-Log "start.ps1 finished"
