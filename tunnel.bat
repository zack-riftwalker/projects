@echo off
rem Optional: a temporary https://xxxx.trycloudflare.com link to this PC's server, for when port forwarding is not possible.
rem Run start.bat first. Needs cloudflared:  winget install Cloudflare.cloudflared
where cloudflared >nul 2>nul
if errorlevel 1 (
  echo cloudflared not found. Install it with:  winget install Cloudflare.cloudflared
  pause
  exit /b 1
)
cloudflared tunnel --url http://localhost:3000
pause
