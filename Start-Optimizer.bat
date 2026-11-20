@echo off
@chcp 65001 >nul
setlocal
cd /d "%~dp0"
title Windows 11 Master Optimizer

set "SCRIPT_PATH=%~dp0Win11Optimizer.ps1"
if not exist "%SCRIPT_PATH%" (
    if exist "%~dp0Optimizer\Win11Optimizer.ps1" (
        set "SCRIPT_PATH=%~dp0Optimizer\Win11Optimizer.ps1"
    )
)

if not exist "%SCRIPT_PATH%" (
    echo [ERROR] Win11Optimizer.ps1 not found in "%~dp0" or "%~dp0Optimizer\"!
    echo Please ensure the script files are in the same folder.
    pause
    exit /b 1
)

net session >nul 2>&1
if %errorlevel% equ 0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
) else (
    echo [UAC] Requesting Administrator privileges...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File """"%SCRIPT_PATH%""""' -Verb RunAs"
)

if %errorlevel% neq 0 (
    echo.
    echo Error during startup. Press any key to exit...
    pause >nul
)
