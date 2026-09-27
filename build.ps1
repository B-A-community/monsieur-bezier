# Собирает релиз Monsieur Bézier в dist\:
#   monsieur_bezier-<версия>-rus.rbz / -eng.rbz   — сами плагины;
#   monsieur_bezier-<версия>-rus.zip / -eng.zip   — плагин + PDF-инструкция.
#   .\build.ps1             — обе версии
#   .\build.ps1 -Lang en    — только английская
#   .\build.ps1 -NoZip      — только .rbz, без архивов (для проверки)
# Языковой пакет — тот же исходник, в копии подменяется строка LANG в
# src\monsieur_bezier\lang.rb (Ruby) и src\monsieur_bezier\html\i18n.js (окна).
# PDF-инструкции собирает tools\build_guides.ps1 из docs\guide-*.html.
# Пакуем через .NET ZipFile поштучно: Compress-Archive в PS 5.1 пишет пути с
# "\", и SketchUp разложит такой архив в один файл вместо папки.
param(
  [ValidateSet('ru', 'en', 'all')][string]$Lang = 'all',
  [switch]$NoZip
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$src  = Join-Path $PSScriptRoot "src"
$docs = Join-Path $PSScriptRoot "docs"
$dist = Join-Path $PSScriptRoot "dist"
New-Item -ItemType Directory -Force $dist | Out-Null

$version = (Select-String -Path (Join-Path $src "monsieur_bezier.rb") -Pattern "VERSION\s*=\s*'([^']+)'").Matches[0].Groups[1].Value
$suffix = @{ ru = 'rus'; en = 'eng' }
$langs = if ($Lang -eq 'all') { @('ru', 'en') } else { @($Lang) }
$utf8 = New-Object System.Text.UTF8Encoding $false

function Add-Entry($zip, $file, $name) {
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
    $zip, $file, $name, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
}

foreach ($l in $langs) {
  $base  = "monsieur_bezier-{0}-{1}" -f $version, $suffix[$l]
  $stage = Join-Path $dist ("stage-" + [guid]::NewGuid().ToString('N'))
  Copy-Item $src $stage -Recurse
  Copy-Item (Join-Path $PSScriptRoot 'LICENSE') (Join-Path $stage 'monsieur_bezier/LICENSE')
  Copy-Item (Join-Path $PSScriptRoot 'AUTHORS') (Join-Path $stage 'monsieur_bezier/AUTHORS')

  foreach ($f in @('monsieur_bezier\lang.rb', 'monsieur_bezier\html\i18n.js')) {
    $p = Join-Path $stage $f
    $text = [System.IO.File]::ReadAllText($p, $utf8)
    $patched = $text -replace "LANG = '[a-z]{2}'", "LANG = '$l'"
    if ($patched -eq $text -and $l -ne 'ru') { throw "Не нашёл строку LANG в $f" }
    [System.IO.File]::WriteAllText($p, $patched, $utf8)
  }

  # 1. Плагин
  $rbz = Join-Path $dist "$base.rbz"
  Remove-Item $rbz -ErrorAction SilentlyContinue
  $zip = [System.IO.Compression.ZipFile]::Open($rbz, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    Get-ChildItem $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
      Add-Entry $zip $_.FullName ($_.FullName.Substring($stage.Length + 1) -replace '\\', '/')
    }
  } finally {
    $zip.Dispose()
  }
  $resolvedStage = (Resolve-Path -LiteralPath $stage).Path
  $resolvedDist = (Resolve-Path -LiteralPath $dist).Path
  if (-not $resolvedStage.StartsWith($resolvedDist + [IO.Path]::DirectorySeparatorChar)) {
    throw "Build staging path is outside dist: $resolvedStage"
  }
  Remove-Item -LiteralPath $resolvedStage -Recurse -Force
  Write-Host "Готово: $rbz"

  # 2. Архив для релиза: плагин + инструкция
  if ($NoZip) { continue }
  $pdfName = "monsieur_bezier-{0}-guide-{1}.pdf" -f $version, $suffix[$l]
  $pdf = Join-Path $docs $pdfName
  if (-not (Test-Path $pdf)) { throw "Нет инструкции $pdf — сначала tools\build_guides.ps1" }
  $arc = Join-Path $dist "$base.zip"
  Remove-Item $arc -ErrorAction SilentlyContinue
  $zip = [System.IO.Compression.ZipFile]::Open($arc, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    Add-Entry $zip $rbz "$base.rbz"
    Add-Entry $zip $pdf $pdfName
  } finally {
    $zip.Dispose()
  }
  Write-Host "Готово: $arc"
}
