<#
.SYNOPSIS
    Met à jour le container DevBox si une nouvelle image est publiée.
.DESCRIPTION
    Télécharge l'image configurée (par défaut :latest). Si elle diffère de celle du
    container, le container est supprimé puis recréé ; le volume /home/dev est conservé.
    Lancé automatiquement par la tâche planifiée « \WSLC\DevBox Update ».
.PARAMETER Force
    Recrée le container même s'il est à jour ou si une session est ouverte.
#>
[CmdletBinding()]
param([switch]$Force)
. (Join-Path $PSScriptRoot 'DevBox.Common.ps1')

try {
    Assert-DevBoxPrerequisites
    $config = Get-DevBoxConfig

    Invoke-Wslc pull --quiet $config.Image | Out-Null
    $imageId = Get-DevBoxImageId -Config $config
    $container = Get-DevBoxContainer -Config $config

    if ($container -and $container.Image -eq $imageId -and -not $Force) {
        Write-Verbose 'DevBox à jour.'
        return
    }

    if ($container -and $container.State.Running -and $config.SkipUpdateWhenBusy -and -not $Force) {
        if (Test-DevBoxBusy -Config $config) {
            Write-DevBoxLog "Nouvelle image disponible ($($imageId.Substring(7, 12))) mais une session est ouverte : mise à jour reportée."
            return
        }
    }

    if ($container) {
        Invoke-Wslc remove --force $config.ContainerName | Out-Null
    }
    New-DevBoxContainer -Config $config
    Invoke-Wslc image prune --force | Out-Null

    Write-DevBoxLog "DevBox mis à jour : $($config.Image) ($($imageId.Substring(7, 12)))."
}
catch {
    Write-DevBoxLog "ERREUR mise à jour : $_"
    exit 1
}
