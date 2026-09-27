# Печатает PDF-инструкции из docs\guide-rus.html и docs\guide-eng.html в
# docs\monsieur_bezier-<версия>-guide-rus.pdf / -eng.pdf — их кладёт в
# релизные архивы build.ps1. Печатает Edge (или Chrome) без окна; размер
# страницы и поля заданы в самих html через @page.
#   .\tools\build_guides.ps1
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root "docs"
$version = (Select-String -Path (Join-Path $root "src\monsieur_bezier.rb") -Pattern "VERSION\s*=\s*'([^']+)'").Matches[0].Groups[1].Value

$browser = @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { throw "Не нашёл ни Edge, ни Chrome — печатать PDF нечем" }

# Отдельный профиль: иначе браузер прицепится к уже открытому окну
# пользователя и headless-печать тихо не сработает.
$profile = Join-Path $env:TEMP "monsieur_bezier_pdf_profile"

foreach ($suffix in @('rus', 'eng')) {
  $html = Join-Path $docs "guide-$suffix.html"
  $pdf  = Join-Path $docs ("monsieur_bezier-{0}-guide-{1}.pdf" -f $version, $suffix)
  Remove-Item $pdf -ErrorAction SilentlyContinue
  $url = "file:///" + ($html -replace '\\', '/')
  # Start-Process, а не "&": браузер пишет «bytes written» в stderr, и
  # PowerShell 5.1 при ErrorActionPreference=Stop принимает это за ошибку.
  $log = Join-Path $env:TEMP "monsieur_bezier_pdf.log"
  Start-Process -FilePath $browser -Wait -NoNewWindow -RedirectStandardError $log -ArgumentList @(
    '--headless', '--disable-gpu', '--no-pdf-header-footer',
    "--user-data-dir=`"$profile`"", "--print-to-pdf=`"$pdf`"", "`"$url`"")
  # Браузер может вернуться раньше, чем файл дописан, — ждём появления.
  for ($i = 0; $i -lt 50 -and -not (Test-Path $pdf); $i++) { Start-Sleep -Milliseconds 200 }
  if (-not (Test-Path $pdf)) { throw "PDF не появился: $pdf" }
  Write-Host ("Готово: {0} ({1:N0} байт)" -f $pdf, (Get-Item $pdf).Length)
}
