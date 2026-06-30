@echo off
REM Double-click this to open the focus GUI control panel.
REM It needs ffplay (FFmpeg) on PATH:  winget install -e --id Gyan.FFmpeg
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0focus-gui.ps1"
