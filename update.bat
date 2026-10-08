@echo off
rem Downloads the newest CLAWD from GitHub and installs it over this folder (saves, settings and node_modules are kept).
rem Everything is on one line on purpose: this file may be replaced while it runs.
cd /d "%~dp0" & powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\update.ps1" %* & exit /b
