param(
  [string]$Python = 'python'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$venvPath = Join-Path $projectRoot '.media-tools-venv'
$requirements = Join-Path $projectRoot 'media-tools-requirements.txt'

& $Python -m venv $venvPath
& (Join-Path $venvPath 'Scripts\python.exe') -m pip install --upgrade pip
& (Join-Path $venvPath 'Scripts\python.exe') -m pip install -r $requirements

Write-Host "Installed pinned media tools into $venvPath"
