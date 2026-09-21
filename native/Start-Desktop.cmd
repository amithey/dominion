@echo off
setlocal
set "GODOT_EXE=%~dp0..\.local-tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot 4.7.2 was not found. Open native/godot/project.godot with your Godot editor.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0prepare-desktop.ps1"
if errorlevel 1 exit /b 1
"%GODOT_EXE%" --headless --editor --path "%~dp0godot" --import
if errorlevel 1 exit /b 1
start "DOMINION Desktop Prototype" "%GODOT_EXE%" --path "%~dp0godot"
