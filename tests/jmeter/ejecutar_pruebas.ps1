# ==============================================================================
# Script de Ejecución Automatizada de Pruebas de Carga con Apache JMeter
# Proyecto: SysQuest Backend
# ==============================================================================

param(
    [int]$Threads = 25,
    [int]$RampUp = 5,
    [int]$Loop = 4,
    [string]$HostTarget = "jctulgfdweeurqbmugot.supabase.co"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$JMeterPath = "C:\Users\Andres\Desktop\jmeter\apache-jmeter-5.6.3\bin\jmeter.bat"
if (!(Test-Path $JMeterPath)) {
    # Alternativa si se extrajo directamente en C:\Users\Andres\Desktop\jmeter\bin
    $JMeterPath = "C:\Users\Andres\Desktop\jmeter\bin\jmeter.bat"
}

if (!(Test-Path $JMeterPath)) {
    Write-Error "No se encontró el ejecutable de JMeter en $JMeterPath. Por favor verifica la ruta de extracción."
    exit 1
}

$TestPlan = Join-Path $ScriptDir "sysquest_load_test.jmx"
$ResultsFile = Join-Path $ScriptDir "resultados.csv"
$ReportDir = Join-Path $ScriptDir "reporte_html"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   EJECUTANDO PRUEBAS DE CARGA SYSQUEST CON APACHE JMETER " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Host Destino       : $HostTarget" -ForegroundColor Yellow
Write-Host "Usuarios (Hilos)   : $Threads concurrentes" -ForegroundColor Yellow
Write-Host "Rampa de Aceleración: $RampUp segundos" -ForegroundColor Yellow
Write-Host "Iteraciones        : $Loop ciclos" -ForegroundColor Yellow
Write-Host "Total Peticiones   : $($Threads * $Loop * 3) peticiones estimadas" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Limpieza de reportes anteriores
if (Test-Path $ResultsFile) {
    Remove-Item $ResultsFile -Force
}
if (Test-Path $ReportDir) {
    Remove-Item $ReportDir -Recurse -Force
}

# 2. Ejecución headless / non-GUI de JMeter generando Dashboard HTML
$args = @(
    "-n",
    "-t", "`"$TestPlan`"",
    "-l", "`"$ResultsFile`"",
    "-e",
    "-o", "`"$ReportDir`"",
    "-Jhost=$HostTarget",
    "-Jthreads=$Threads",
    "-Jrampup=$RampUp",
    "-Jloop=$Loop"
)

Write-Host "Iniciando motor JMeter en modo non-GUI..." -ForegroundColor Green
& $JMeterPath @args

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  ¡PRUEBA FINALIZADA EXITOSAMENTE!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Resultados CSV guardados en: $ResultsFile" -ForegroundColor White
Write-Host "Dashboard HTML generado en : $ReportDir\index.html" -ForegroundColor White

if (Test-Path "$ReportDir\index.html") {
    Write-Host "Abriendo Dashboard de Rendimiento en el navegador..." -ForegroundColor Cyan
    Start-Process "$ReportDir\index.html"
}
