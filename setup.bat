@echo off
REM ============================================================
REM  gcWeaselSettings launcher
REM  Double-click to run setup.ps1 (which self-elevates via UAC).
REM ============================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
