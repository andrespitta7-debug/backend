@echo off
echo ========================================================
echo    EJECUTANDO PRUEBAS DE CARGA SYSQUEST - APACHE JMETER
echo ========================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ejecutar_pruebas.ps1"
pause
