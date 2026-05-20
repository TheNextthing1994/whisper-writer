@echo off
cd /d "%~dp0"
call venv\Scripts\activate.bat
set "PATH=%CD%\venv\Lib\site-packages\torch\lib;%PATH%"
set PYTHONUNBUFFERED=1
python -u run.py > whisperwriter.log 2>&1
echo.
echo === Programm beendet. Logs: ===
echo.
type whisperwriter.log
pause
