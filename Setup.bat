@echo off
setlocal
title TaskPlopp einrichten
echo.
echo TaskPlopp - lokale Einrichtung
echo =============================
echo.
echo Erstellt oder aktualisiert die Desktop-Verknuepfung.
echo TaskPlopp bleibt in diesem Ordner. Bitte danach nicht verschieben.
echo Vorhandene Einstellungen bleiben erhalten. Kein Administrator noetig.
echo.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Shortcut.ps1" -Update
if errorlevel 1 goto failed
echo.
echo Einrichtung abgeschlossen.
echo Jetzt TaskPlopp auf dem Desktop doppelt anklicken.
echo Diktat kann spaeter in TaskPlopp eingerichtet werden.
echo.
pause
exit /b 0

:failed
echo.
echo Einrichtung fehlgeschlagen. Bitte die Fehlermeldung oben beachten.
echo.
pause
exit /b 1
