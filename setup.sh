#!/usr/bin/env bash
set -euo pipefail

# Minimal installer: ensure PowerShell (pwsh) is installed, then hand off to setup.ps1
INSTALL_DIR="${1:-$(pwd)}"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO=sudo
  else
    echo "This script must be run as root or with sudo available." >&2
    exit 1
  fi
fi

echo "Using install directory: ${INSTALL_DIR} (you may pass a different path as the first arg)"

if [ ! -f "${INSTALL_DIR}/setup.ps1" ]; then
  echo "Error: setup.ps1 not found in ${INSTALL_DIR}. Please ensure you cloned the repo and are running this script from the repo root or pass the correct install directory." >&2
  exit 1
fi

if ! command -v pwsh >/dev/null 2>&1; then
  echo "PowerShell (pwsh) not found. Installing via snap..."
  $SUDO apt-get update -y
  $SUDO apt-get install -y snapd
  $SUDO snap install powershell --classic
fi

PWSH_CMD="$(command -v pwsh)"
if [ -z "${PWSH_CMD}" ]; then
  echo "Failed to locate pwsh after attempted install. Please install PowerShell and re-run." >&2
  exit 1
fi

echo "Invoking PowerShell setup script: ${PWSH_CMD} ${INSTALL_DIR}/setup.ps1"
# Run the PowerShell script as root to avoid repeated sudo prompts inside it
$SUDO "${PWSH_CMD}" -NoProfile -ExecutionPolicy Bypass -File "${INSTALL_DIR}/setup.ps1" "${INSTALL_DIR}"

echo "setup.ps1 completed (or failed). Check logs for details."
