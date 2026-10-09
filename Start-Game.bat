@echo off
setlocal
if exist "%~dp0dist\DOMINION.exe" (
    start "" /D "%~dp0dist" "%~dp0dist\DOMINION.exe"
) else (
    echo DOMINION.exe is missing. Build the Windows game using native\build-windows.ps1.
    echo See native\README.md for the native Godot project and build requirements.
    pause
    exit /b 1
)
endlocal
