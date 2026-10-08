@echo off
setlocal
cd /d %~dp0
echo.
echo  CLAWD co-op on Cloudflare - deploy
echo  ==================================
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is not installed. Install the LTS version from https://nodejs.org and run this file again.
  pause
  exit /b 1
)

if not exist node_modules (
  echo Installing wrangler - first time only...
  call npm install
  if errorlevel 1 ( echo npm install failed. & pause & exit /b 1 )
)

rem "wrangler whoami" also exits with 0 when you are NOT logged in, so look at what it says
call npx wrangler whoami 2>&1 | findstr /i /c:"You are logged in" >nul
if errorlevel 1 (
  echo Opening the browser so you can log in to Cloudflare - a free account is enough...
  call npx wrangler login
  if errorlevel 1 ( echo Login failed. & pause & exit /b 1 )
)

echo.
echo Uploading the game and the relay...
call npx wrangler deploy
if errorlevel 1 (
  echo.
  echo Deploy failed. Read the message above. If it mentions Durable Objects, check that wrangler.jsonc still has the "migrations" block with new_sqlite_classes - the free plan needs SQLite-backed objects.
  pause
  exit /b 1
)

rem the host key is a secret: it stays in Cloudflare and survives later deploys
call npx wrangler secret list 2>nul | findstr /c:"HOST_KEY" >nul
if errorlevel 1 (
  set ASK=Y
) else (
  set ASK=N
  set /p ASK=A host key is already set. Change it? [y/N] 
)
if /i "%ASK%"=="Y" (
  echo.
  echo Choose the HOST KEY. Only you need it: it lets your browser be the host. Type it and press Enter - nothing is shown while you type.
  call npx wrangler secret put HOST_KEY
  if errorlevel 1 ( echo Setting the host key failed. Run this file again. & pause & exit /b 1 )
)

echo.
echo Done. Open the link printed above ^(ending in .workers.dev^) once with ?host at the end,
echo click 2P, then Host, and enter your host key. Then send the plain link and the 6-digit code to your friend.
echo.
pause
