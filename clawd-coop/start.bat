@echo off
cd /d %~dp0
if not exist node_modules (
  echo Installing... first time only
  call npm install
)
where cloudflared >nul 2>nul
if %errorlevel%==0 (
  start "Tunnel - copy the trycloudflare.com link" cmd /k cloudflared tunnel --url http://localhost:3000
) else (
  echo cloudflared not found - online play needs it: winget install Cloudflare.cloudflared
)
start "" http://localhost:3000
node server.js
pause
