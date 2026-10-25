@echo off
setlocal
if exist "%~dp0build\regional-preview\DOMINION.exe" (
    start "" /D "%~dp0build\regional-preview" "%~dp0build\regional-preview\DOMINION.exe"
) else (
    start "" /D "%~dp0native\godot" "%~dp0.local-tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0native\godot"
)
endlocal
