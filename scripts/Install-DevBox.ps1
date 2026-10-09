<#
.SYNOPSIS
    Crée le container DevBox et installe la mise à jour automatique.
.DESCRIPTION
    1. crée le volume persistant /home/dev
    2. télécharge l'image et crée le container
    3. enregistre la tâche planifiée « \WSLC\DevBox Update » (ouverture de session + quotidienne)
    4. ajoute un profil « DevBox (wslc) » dans Windows Terminal
    Le script est idempotent : on peut le relancer sans risque.
    À exécuter depuis un terminal NON administrateur.
#>
[CmdletBinding()]
param(
    [switch]$NoScheduledTask,
    [switch]$NoTerminalProfile
)
. (Join-Path $PSScriptRoot 'DevBox.Common.ps1')

Assert-DevBoxPrerequisites
$config = Get-DevBoxConfig

# 1. Volume persistant
$volumes = Invoke-Wslc volume list --quiet
if ($volumes -notcontains $config.HomeVolume) {
    Invoke-Wslc volume create $config.HomeVolume | Out-Null
    Write-DevBoxLog "Volume '$($config.HomeVolume)' créé."
}

# 2. Image + container
if (Get-DevBoxContainer -Config $config) {
    Write-Host "Container '$($config.ContainerName)' déjà présent : vérification des mises à jour."
    & (Join-Path $PSScriptRoot 'Update-DevBox.ps1')
}
else {
    Write-Host "Téléchargement de $($config.Image) (plusieurs Go la première fois)..."
    Invoke-Wslc pull $config.Image | Out-Null
    New-DevBoxContainer -Config $config
    Write-DevBoxLog "Container '$($config.ContainerName)' créé depuis $($config.Image)."
}

# 3. Tâche planifiée de mise à jour (contexte utilisateur, non élevé)
if (-not $NoScheduledTask) {
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $updateScript = Join-Path $PSScriptRoot 'Update-DevBox.ps1'
    # conhost --headless : aucune fenêtre ne s'ouvre pendant la mise à jour
    $action = New-ScheduledTaskAction -Execute 'conhost.exe' `
        -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$updateScript`""
    $atLogon = New-ScheduledTaskTrigger -AtLogOn -User $user
    $atLogon.Delay = 'PT5M'
    $daily = New-ScheduledTaskTrigger -Daily -At $config.UpdateTime
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask -TaskPath '\WSLC\' -TaskName 'DevBox Update' -Action $action `
        -Trigger $atLogon, $daily -Settings $settings -Principal $principal `
        -Description 'Met à jour le container wslc DevBox depuis GHCR (voir README du dépôt WSLC).' `
        -Force | Out-Null
    Write-DevBoxLog "Tâche planifiée '\WSLC\DevBox Update' enregistrée (ouverture de session + $($config.UpdateTime))."
}

# 4. Profil Windows Terminal (fragment JSON)
if (-not $NoTerminalProfile) {
    $fragmentDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\WSLC-DevBox'
    New-Item -ItemType Directory -Path $fragmentDir -Force | Out-Null
    $enterScript = Join-Path $PSScriptRoot 'Enter-DevBox.ps1'
    $fragment = @{
        profiles = @(@{
            guid        = '{6b0e7a52-3c1f-4d8e-9a57-2f5d0c4e8b11}'
            name        = 'DevBox (wslc)'
            commandline = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$enterScript`""
            icon        = 'ms-appx:///ProfileIcons/pwsh.png'
        })
    }
    $fragment | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $fragmentDir 'devbox.json') -Encoding UTF8
    Write-Host 'Profil Windows Terminal « DevBox (wslc) » ajouté (redémarrez Windows Terminal).'
}

Write-Host ''
Write-Host "Prêt. Ouvrez une session avec : $(Join-Path $PSScriptRoot 'Enter-DevBox.ps1')"
