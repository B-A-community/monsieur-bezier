# Копирует плагин в папку Plugins SketchUp для разработки.
#   .\dev_install.ps1                — SketchUp 2024
#   .\dev_install.ps1 -Version 2025  — SketchUp 2025
#   .\dev_install.ps1 -Version 2026  — SketchUp 2026
# После копирования перезапустите SketchUp (или tools\su_exec.ps1 с load).
param([string]$Version = '2024')
$ErrorActionPreference = "Stop"

$plugins = Join-Path $env:APPDATA "SketchUp\SketchUp $Version\SketchUp\Plugins"
if (-not (Test-Path $plugins)) {
  Write-Error "Не найдена папка плагинов SketchUp ${Version}: $plugins"
}

Copy-Item (Join-Path $PSScriptRoot "src\monsieur_bezier.rb") $plugins -Force
Copy-Item (Join-Path $PSScriptRoot "src\monsieur_bezier") $plugins -Recurse -Force
Write-Host "Установлено в $plugins"
