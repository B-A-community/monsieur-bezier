# Выполняет Ruby-код в запущенном SketchUp через sketchup_mcp_server
# (POST http://127.0.0.1:8080/ruby/execute; код идёт в главный поток SketchUp).
# Несколько SketchUp сразу: 8080 берёт первый, остальные — любой свободный
# порт; он записан в %LOCALAPPDATA%\complex\instances\sketchup-<pid>.json.
# Использование:
#   .\tools\su_exec.ps1 -Code 'Sketchup.version'
#   .\tools\su_exec.ps1 -File .\check.rb
# Горячая перезагрузка плагина после dev_install.ps1:
#   .\tools\su_exec.ps1 -Code 'dir = File.join(Sketchup.find_support_file("Plugins"), "monsieur_bezier"); %w[lang settings bezier bezier_tool about].each { |f| load File.join(dir, f + ".rb") }'
param([string]$Code, [string]$File, [int]$Port = 8080)
if ($File) { $Code = [System.IO.File]::ReadAllText($File, [System.Text.Encoding]::UTF8) }
if (-not $Code) { Write-Error "Нужен -Code или -File"; exit 1 }

$body = [System.Text.Encoding]::UTF8.GetBytes((@{ code = $Code } | ConvertTo-Json -Compress -Depth 3))
$req = [System.Net.HttpWebRequest]::Create("http://127.0.0.1:$Port/ruby/execute")
$req.Method = "POST"; $req.ContentType = "application/json; charset=utf-8"; $req.Timeout = 300000
$s = $req.GetRequestStream(); $s.Write($body, 0, $body.Length); $s.Close()
try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response }
if (-not $resp) { Write-Error "SketchUp не ответил (не запущен, порт $Port не слушает или SketchUp упал)"; exit 1 }
$reader = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
$text = $reader.ReadToEnd(); $reader.Close(); $resp.Close()
$r = $text | ConvertFrom-Json
if ($r.error) { "ERROR: $($r.error)"; $r.backtrace | ForEach-Object { "  $_" }; exit 1 }
if ($r.output) { $r.output | ForEach-Object { $_ } }
"=> $($r.result)"
