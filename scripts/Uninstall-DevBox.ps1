<#
.SYNOPSIS
    Supprime le container DevBox, la tâche planifiée et le profil Windows Terminal.
.PARAMETER RemoveHomeVolume
    Supprime aussi le volume /home/dev (tokens, clés SSH, repos...). Irréversible.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param([switch]$RemoveHomeVolume)
. (Join-Path $PSScriptRoot 'DevBox.Common.ps1')

$config = Get-DevBoxConfig

Unregister-ScheduledTask -TaskPath '\WSLC\' -TaskName 'DevBox Update' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\WSLC-DevBox') -Recurse -Force -ErrorAction SilentlyContinue

if (Get-DevBoxContainer -Config $config) {
    Invoke-Wslc remove --force $config.ContainerName | Out-Null
}
try { Invoke-Wslc rmi $config.Image | Out-Null } catch { Write-Verbose $_ }

if ($RemoveHomeVolume -and $PSCmdlet.ShouldProcess($config.HomeVolume, 'Supprimer le volume et toutes ses données')) {
    Invoke-Wslc volume remove $config.HomeVolume | Out-Null
}
Write-DevBoxLog 'DevBox désinstallé.'
