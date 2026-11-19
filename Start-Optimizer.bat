@echo off
setlocal
cd /d "%~dp0"
title Windows 11 Master Optimizer

net session >nul 2>&1
if %errorlevel% equ 0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Optimizer\Win11Optimizer.ps1"
) else (
    echo [UAC] Requesting Administrator privileges...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \""""%~dp0Optimizer\Win11Optimizer.ps1\""""' -Verb RunAs"
)

if %errorlevel% neq 0 (
    echo.
    echo Error during startup. Press any key to exit...
    pause >nul
)