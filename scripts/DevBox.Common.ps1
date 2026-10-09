# Fonctions partagées par les scripts DevBox. Compatible Windows PowerShell 5.1 et PowerShell 7.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:StateDir = Join-Path $env:LOCALAPPDATA 'wslc-devbox'
$script:LogFile = Join-Path $script:StateDir 'devbox.log'
$script:ContainerUser = 'dev'

function Get-DevBoxConfig {
    $config = Import-PowerShellDataFile (Join-Path $script:RepoRoot 'config\devbox.psd1')
    $localPath = Join-Path $script:RepoRoot 'config\devbox.local.psd1'
    if (Test-Path $localPath) {
        foreach ($entry in (Import-PowerShellDataFile $localPath).GetEnumerator()) {
            $config[$entry.Key] = $entry.Value
        }
    }
    $config
}

function Write-DevBoxLog {
    param([Parameter(Mandatory)][string]$Message)
    if (-not (Test-Path $script:StateDir)) { New-Item -ItemType Directory -Path $script:StateDir | Out-Null }
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
    Write-Host $Message
}

# Appelle wslc et lève une exception si le code retour est non nul.
function Invoke-Wslc {
    # wslc écrit parfois sur stderr : en 5.1, 2>&1 + Stop transformerait ça en exception
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & wslc @args 2>&1 | ForEach-Object { "$_" }
    }
    finally {
        $ErrorActionPreference = $previous
    }
    if ($LASTEXITCODE -ne 0) {
        throw "wslc $($args -join ' ') a échoué (code $LASTEXITCODE) : $($output -join "`n")"
    }
    $output
}

function Assert-DevBoxPrerequisites {
    if (-not (Get-Command wslc -ErrorAction SilentlyContinue)) {
        throw 'wslc introuvable. Installez/mettez à jour WSL : wsl --update'
    }
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning ('Terminal administrateur : wslc utilise une session séparée en mode élevé. ' +
            'Le container ne serait pas visible depuis un terminal normal ni par la tâche planifiée.')
    }
}

# Objet d'inspection du container, ou $null s'il n'existe pas.
function Get-DevBoxContainer {
    param([Parameter(Mandatory)][hashtable]$Config)
    try {
        $json = Invoke-Wslc inspect --type container --format json $Config.ContainerName
        @($json -join '' | ConvertFrom-Json)[0]
    }
    catch { $null }
}

function Get-DevBoxImageId {
    param([Parameter(Mandatory)][hashtable]$Config)
    $json = Invoke-Wslc image inspect --format json $Config.Image
    @($json -join '' | ConvertFrom-Json)[0].Id
}

# Vrai si un processus attaché à un terminal tourne dans le container (session ouverte).
function Test-DevBoxBusy {
    param([Parameter(Mandatory)][hashtable]$Config)
    $ttys = Invoke-Wslc exec $Config.ContainerName ps -eo 'tty='
    @($ttys | Where-Object { $_.Trim() -and $_.Trim() -ne '?' }).Count -gt 0
}

function New-DevBoxContainer {
    param([Parameter(Mandatory)][hashtable]$Config)
    $homeDir = "/home/$script:ContainerUser"
    $arguments = @(
        'run', '--detach',
        '--name', $Config.ContainerName,
        '--hostname', $Config.HostName,
        '--volume', "$($Config.HomeVolume):$homeDir",
        '--env', "TZ=$($Config.TimeZone)",
        '--workdir', $homeDir,
        '--label', 'devbox.managed=true'
    )
    foreach ($mount in $Config.ExtraMounts) { $arguments += '--volume', $mount }
    if ($Config.Memory) { $arguments += '--memory', $Config.Memory }
    if ($Config.Cpus) { $arguments += '--cpus', $Config.Cpus }
    $arguments += $Config.Image

    Invoke-Wslc @arguments | Out-Null
}
