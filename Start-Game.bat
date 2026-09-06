@echo off
setlocal
cd /d "%~dp0"
start "" "http://127.0.0.1:8771/index.html"
python scripts/dev-server.py
endlocal
