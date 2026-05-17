@echo off
cd /d %~dp0

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0scripts\diagnose_compatibility.ps1"
