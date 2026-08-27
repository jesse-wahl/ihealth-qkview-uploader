@echo off
title F5 iHealth QKView Uploader Launcher
echo Starting F5 iHealth QKView Uploader Server...

start "F5 iHealth Server" powershell -NoExit -ExecutionPolicy Bypass -File "%~dp0server.ps1"

timeout /t 2 >nul
echo Opening web interface...
start http://localhost:8921/

echo.
echo Application is running at http://localhost:8921/
echo Keep the server console window open while using the application.
pause
