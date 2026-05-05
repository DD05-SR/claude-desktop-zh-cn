@echo off
cd /d %~dp0

net session >nul 2>&1
if errorlevel 1 (
    echo Requesting admin privileges...
    powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File \"%~dp0scripts\search_lang.ps1\"' -Wait"
    exit /b
)

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0scripts\search_lang.ps1"
