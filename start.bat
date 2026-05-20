@echo off
cd /d "%~dp0"

if not exist venv\Scripts\activate.bat (
	echo Virtuelle Umgebung nicht gefunden. Bitte zuerst die Umgebung erstellen (siehe README).
	pause
	exit /b 1
)

call venv\Scripts\activate.bat
set "PATH=%CD%\venv\Lib\site-packages\torch\lib;%PATH%"
set PYTHONUNBUFFERED=1

REM Starte die App detached. Verwende pythonw.exe wenn vorhanden (kein Konsolenfenster).
if exist "%CD%\venv\Scripts\pythonw.exe" (
	start "" "%CD%\venv\Scripts\pythonw.exe" -u "%CD%\run.py"
) else (
	start "" "%CD%\venv\Scripts\python.exe" -u "%CD%\run.py"
)

exit /b 0
