@echo off
setlocal
cd /d "%~dp0"
title Windows 11 Master Optimizer

set "SCRIPT_PATH=%~dp0Win11Optimizer.ps1"
if not exist "%SCRIPT_PATH%" (
    if exist "%~dp0Optimizer\Win11Optimizer.ps1" (
        set "SCRIPT_PATH=%~dp0Optimizer\Win11Optimizer.ps1"
    )
)

net session >nul 2>&1
if %errorlevel% equ 0 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
) else (
    echo [UAC] Запрос прав Администратора...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \""""%SCRIPT_PATH%\""""' -Verb RunAs"
)

if %errorlevel% neq 0 (
    echo.
    echo Ошибка при запуске. Нажмите любую клавишу для выхода...
    pause >nul
)
