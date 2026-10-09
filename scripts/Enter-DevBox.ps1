<#
.SYNOPSIS
    Ouvre un shell dans le container DevBox (le démarre si besoin).
.EXAMPLE
    .\Enter-DevBox.ps1
.EXAMPLE
    .\Enter-DevBox.ps1 -Shell bash
#>
[CmdletBinding()]
param(
    [ValidateSet('pwsh', 'bash')]
    [string]$Shell
)
. (Join-Path $PSScriptRoot 'DevBox.Common.ps1')

Assert-DevBoxPrerequisites
$config = Get-DevBoxConfig
if (-not $Shell) { $Shell = $config.Shell }

$container = Get-DevBoxContainer -Config $config
if (-not $container) {
    throw "Container '$($config.ContainerName)' introuvable. Lancez d'abord scripts\Install-DevBox.ps1"
}
if (-not $container.State.Running) {
    Invoke-Wslc start $config.ContainerName | Out-Null
}

& wslc exec --interactive --tty --user $script:ContainerUser --workdir "/home/$script:ContainerUser" `
    $config.ContainerName $Shell -l
exit $LASTEXITCODE
