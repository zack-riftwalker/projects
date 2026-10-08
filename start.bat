@echo off
cd /d %~dp0
rem The game server for this PC. Your friend joins on the same Wi-Fi/hotspot, or over the internet through port forwarding (see README.md).
if not exist node_modules\ws (
  echo Installing... first time only
  call npm install --omit=dev --no-audit --no-fund
)
rem Optional co-op difficulty defaults (remove 'rem' to use). LOCK=1 stops the host changing them.
rem set BOSS_HP=50
rem set NPC_HITS=1
rem set NPC_MULT=125
rem set LOCK=1
rem the server opens the browser itself once it is listening, and is restarted if it ever stops (or update.bat replaced it)
:loop
node server.js
echo server stopped, restarting in 2 seconds (close this window to quit)...
timeout /t 2 /nobreak >nul
goto loop
