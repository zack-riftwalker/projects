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
rem the server opens the browser itself once it is listening, and is restarted if it ever stops
:loop
node server.js
echo server stopped, restarting in 2 seconds (close this window to quit)...
timeout /t 2 /nobreak >nul
goto loop
