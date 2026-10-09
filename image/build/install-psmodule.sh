#!/usr/bin/env bash
# Installe un module PowerShell en version exacte depuis PSGallery (scope AllUsers).
# PSGallery coupe parfois les connexions : 3 tentatives avant d'échouer.
# Usage : install-psmodule.sh <Nom> <Version>
set -euo pipefail

for attempt in 1 2 3; do
  if MODULE_NAME="$1" MODULE_VERSION="$2" pwsh -NoLogo -NoProfile -Command '
      $ErrorActionPreference = "Stop"
      Install-PSResource -Name $env:MODULE_NAME -Version $env:MODULE_VERSION -Scope AllUsers -TrustRepository -AcceptLicense -Quiet
      Get-InstalledPSResource -Scope AllUsers -Name $env:MODULE_NAME | Format-Table Name, Version'; then
    exit 0
  fi
  echo "Échec de l'installation de $1 $2 (tentative $attempt/3)" >&2
  sleep $((attempt * 15))
done
exit 1
