# CLAWD updater: downloads the latest version from GitHub and installs it over this folder.
# Run it with update.bat. Your saves live in the browser, so they are never touched; neither are
# node_modules, coop-config.json and the Cloudflare login (.wrangler).
param([switch]$Force)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'          # the progress bar makes Invoke-WebRequest many times slower
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = 'zack-riftwalker/projects'
$Dir = Split-Path -Parent $PSScriptRoot           # the game folder (this script lives in tools\)
$Branch = 'main'
$bf = Join-Path $Dir 'update-branch.txt'           # optional: another branch to follow
if (Test-Path $bf) { $b = (Get-Content $bf -Raw).Trim(); if ($b) { $Branch = $b } }
$Keep = @('node_modules', '.wrangler', '.git', '_update', 'coop-config.json', '.dev.vars', 'version.txt', 'update-branch.txt', '.clawd-files')

function Done($msg, $code) { Write-Host ''; Write-Host $msg; Write-Host ''; Read-Host 'Press Enter to close' | Out-Null; exit $code }

Write-Host ''
Write-Host ' CLAWD updater'
Write-Host ' ============='
Write-Host (' folder: ' + $Dir)
Write-Host (' source: github.com/' + $Repo + ' (' + $Branch + ')')
Write-Host ''

# ---------- 1. is there anything new? ----------
$vf = Join-Path $Dir 'version.txt'
$have = ''; if (Test-Path $vf) { $have = (Get-Content $vf -Raw).Trim() }
$sha = ''; $msg = ''; $when = ''
try {
  $c = Invoke-RestMethod -UseBasicParsing -Headers @{ 'User-Agent' = 'clawd-updater' } -Uri ('https://api.github.com/repos/' + $Repo + '/commits/' + $Branch) -TimeoutSec 20
  $sha = $c.sha; $msg = ($c.commit.message -split "`n")[0]; $when = $c.commit.committer.date
} catch { Write-Host ' (could not ask GitHub for the latest version - downloading anyway)' }
if ($sha -and $sha -eq $have -and -not $Force) { Done (' Already up to date (' + $sha.Substring(0, 7) + ').') 0 }
if ($sha) { Write-Host (' new version: ' + $sha.Substring(0, 7) + '  ' + $when + '  "' + $msg + '"') }

# ---------- 2. download and unpack into _update\ (inside the game folder, so nothing depends on %TEMP%) ----------
$tmp = Join-Path $Dir '_update'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory $tmp | Out-Null
$zip = Join-Path $tmp 'clawd.zip'
$ref = $Branch; if ($sha) { $ref = $sha }           # the exact commit we just announced
Write-Host ' downloading...'
try {
  Invoke-WebRequest -UseBasicParsing -Uri ('https://codeload.github.com/' + $Repo + '/zip/' + $ref) -OutFile $zip -TimeoutSec 300
} catch {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Done (' Download failed: ' + $_.Exception.Message + "`n If GitHub is blocked on your line, turn the VPN on and run update.bat again.") 1
}
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1
if (-not $src -or -not (Test-Path (Join-Path (Join-Path $src.FullName 'public') 'index.html')) -or -not (Test-Path (Join-Path $src.FullName 'server.js'))) {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  Done ' The download does not look like CLAWD (public\index.html or server.js missing). Nothing was changed.' 1
}
$root = $src.FullName

# ---------- 3. copy what changed ----------
$files = Get-ChildItem $root -Recurse -File | ForEach-Object { $_.FullName.Substring($root.Length + 1) }
$files = $files | Where-Object { $Keep -notcontains ($_ -split '[\\/]')[0] }
# package.json first (npm may need it), server.js last (the running server restarts itself when it changes)
$files = @($files | Where-Object { $_ -eq 'package.json' }) + @($files | Where-Object { $_ -ne 'package.json' -and $_ -ne 'server.js' }) + @($files | Where-Object { $_ -eq 'server.js' })
$changed = @()
foreach ($f in $files) {
  $from = Join-Path $root $f; $to = Join-Path $Dir $f
  $same = (Test-Path $to) -and ((Get-Item $to).Length -eq (Get-Item $from).Length) -and ((Get-FileHash $to).Hash -eq (Get-FileHash $from).Hash)
  if ($same) { continue }
  $d = Split-Path -Parent $to; if (-not (Test-Path $d)) { New-Item -ItemType Directory $d -Force | Out-Null }
  $ok = $false
  for ($i = 0; $i -lt 5 -and -not $ok; $i++) {         # a file can be busy for a moment (antivirus, the server reading it)
    try { Copy-Item $from $to -Force; $ok = $true } catch { Start-Sleep -Milliseconds 400 }
  }
  if (-not $ok) { Write-Host (' could not write ' + $f + ' (is it open somewhere?)') } else { $changed += $f }
}

# files the previous version installed that the new one no longer has
$mf = Join-Path $Dir '.clawd-files'
$removed = @()
if (Test-Path $mf) {
  foreach ($old in (Get-Content $mf)) {
    if ($old -and ($files -notcontains $old) -and ($Keep -notcontains ($old -split '[\\/]')[0])) {
      $p = Join-Path $Dir $old
      if (Test-Path $p -PathType Leaf) { Remove-Item $p -Force -ErrorAction SilentlyContinue; $removed += $old }
    }
  }
}
Set-Content -Path $mf -Value $files -Encoding UTF8
if ($sha) { Set-Content -Path $vf -Value $sha -Encoding ASCII }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

# ---------- 4. dependencies (only the small "ws" package the server needs) ----------
$needNpm = ($changed -contains 'package.json') -or -not (Test-Path (Join-Path (Join-Path $Dir 'node_modules') 'ws'))
if ($needNpm) {
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host ' installing the server package...'
    Push-Location $Dir; try { & npm install --omit=dev --no-audit --no-fund | Out-Host } finally { Pop-Location }
  } else { Write-Host ' Node.js is not installed: get the LTS version from https://nodejs.org' }
}

# ---------- 5. report ----------
Write-Host ''
if ($changed.Count -eq 0 -and $removed.Count -eq 0) { Write-Host ' All files were already current.' }
else {
  Write-Host (' Updated ' + $changed.Count + ' file(s)' + $(if ($removed.Count) { ', removed ' + $removed.Count } else { '' }) + ':')
  foreach ($f in ($changed | Select-Object -First 15)) { Write-Host ('   ' + $f) }
  if ($changed.Count -gt 15) { Write-Host ('   ... and ' + ($changed.Count - 15) + ' more') }
}
Write-Host ''
if ($changed -contains 'server.js') { Write-Host ' * If start.bat is running, the server restarts by itself in a few seconds.' }
Write-Host ' * Reload the game on BOTH devices (PC: Ctrl+F5, phone: close the tab and open the link again).'
if (Test-Path (Join-Path $Dir '.wrangler')) { Write-Host ' * You use the Cloudflare version too: run deploy.bat to put this update online.' }
Done ' Update finished.' 0
