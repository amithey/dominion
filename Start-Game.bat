@echo off
setlocal
cd /d "%~dp0"
start "" "http://localhost:8765/index.html"
python -m http.server 8765 --bind 127.0.0.1
endlocal
