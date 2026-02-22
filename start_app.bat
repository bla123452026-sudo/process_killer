@echo off
setlocal
cd /d "%~dp0"

:MENU
cls
echo ==========================================
echo        WINDOWS PROCESS KILLER STARTER
echo ==========================================
echo.
echo  1. Start op de ACHTERGROND (Onzichtbaar)
echo  2. Open de APP (Zichtbaar venster voor instellen)
echo  3. Sluiten
echo.
set /p keuze="Maak een keuze (1, 2 of 3): "

if "%keuze%"=="1" goto BACKGROUND
if "%keuze%"=="2" goto FOREGROUND
if "%keuze%"=="3" exit
goto MENU

:BACKGROUND
cls
echo Bezig met opstarten op de achtergrond...
if not exist "process_killer.ps1" goto ERROR
start /min powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0process_killer.ps1"
echo SUCCESS: De Process Killer is nu actief in het systeemvak (bij de klok).
timeout /t 3 >nul
exit

:FOREGROUND
cls
echo Bezig met opstarten van het venster...
if not exist "process_killer.ps1" goto ERROR
powershell.exe -NoExit -ExecutionPolicy Bypass -File "%~dp0process_killer.ps1"
exit

:ERROR
echo.
echo [FOUT] Kan het bestand "process_killer.ps1" niet vinden!
echo Zorg ervoor dat dit .bat bestand in dezelfde map staat als het script.
pause
goto MENU