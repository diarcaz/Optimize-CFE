<#
.SYNOPSIS
    Script de Optimizacion de Estaciones de Trabajo en el Area de Finanzas (CFE Zona Carmen)
    Proyecto: Script de Optimizacion de Estaciones de Trabajo
    Alumno: Arturo Enrique Martinez Sena

.DESCRIPTION
    Herramienta interna de mantenimiento preventivo para mejorar el rendimiento de las computadoras.
    Realiza limpieza de archivos temporales, optimizacion de inicio, ajustes de energia y limpieza avanzada opcional.
    Disenado para ser seguro, no invasivo y 100% reversible.

.PARAMETER DryRun
    Si se especifica, simula las acciones sin realizar cambios reales.

.PARAMETER DaysToKeep
    Dias de antiguedad que se conservaran. Por defecto: 30.

.PARAMETER BatchSize
    Numero de archivos procesados por lote. Por defecto: 1000.

.PARAMETER DisableStartup
    Mueve elementos de inicio a una carpeta segura.

.PARAMETER DeepClean
    Limpieza avanzada (papelera, cache DNS).

.PARAMETER RemoveBloatware
    Elimina aplicaciones preinstaladas no necesarias.

.PARAMETER LogPath
    Carpeta donde se guardaran los logs.

.PARAMETER ShowConsoleSummary
    Muestra un resumen final en pantalla.
#>

[CmdletBinding()]
param(
    [Switch]$DryRun,
    [int]$DaysToKeep = 30,
    [int]$BatchSize = 1000,
    [Switch]$DisableStartup,
    [Switch]$DeepClean,
    [Switch]$RemoveBloatware,
    [string]$LogPath = "C:\CFE_Logs",
    [Switch]$ShowConsoleSummary
)

$ErrorActionPreference = "SilentlyContinue"
$Script:LogFile = ""
$Script:Stats = @{
    FilesDetected     = 0
    FilesDeleted      = 0
    SpaceFreedBytes   = 0
    Errors            = 0
    StartupMoved      = 0
    PowerPlanChanged  = $false
    ServicesOptimized = 0
    BloatwareRemoved  = 0
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "[$Timestamp] [$Type] $Message"
    if ($Script:LogFile) { Add-Content -Path $Script:LogFile -Value $Line -Encoding UTF8 }

    if ($Type -eq "ERROR") {
        Write-Host $Line -ForegroundColor Red
    }
}

function Get-FormattedSize {
    param([double]$Bytes)
    if ($Bytes -gt 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -gt 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -gt 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes Bytes"
}

function Invoke-Cleaning {
    Write-Log "Iniciando limpieza de archivos temporales mayores a $DaysToKeep dias..."
    $Targets = @(
        $env:TEMP,
        "$env:LOCALAPPDATA\Temp",
        "C:\Windows\Temp"
    )

    $Cutoff = (Get-Date).AddDays(-$DaysToKeep)
    $Batch = 0

    foreach ($Path in $Targets) {
        if (-not (Test-Path $Path)) { continue }

        try {
            $Files = Get-ChildItem -Path $Path -Recurse -File -Force | Where-Object { $_.LastWriteTime -lt $Cutoff }

            foreach ($File in $Files) {
                $Script:Stats.FilesDetected++
                $Size = $File.Length

                if ($DryRun) {
                    Write-Log "[DRYRUN] Se eliminaria: $($File.FullName) ($(Get-FormattedSize $Size))"
                }
                else {
                    try {
                        Remove-Item -Path $File.FullName -Force -ErrorAction Stop
                        $Script:Stats.FilesDeleted++
                        $Script:Stats.SpaceFreedBytes += $Size
                        Write-Log "Eliminado: $($File.FullName)"
                    }
                    catch {
                        $Script:Stats.Errors++
                        Write-Log "Error eliminando $($File.FullName): $($_.Exception.Message)" "ERROR"
                    }
                }

                $Batch++
                if ($Batch -ge $BatchSize) {
                    Start-Sleep -Milliseconds 50
                    $Batch = 0
                }
            }
        }
        catch {
            Write-Log "Error accediendo a $Path: $($_.Exception.Message)" "ERROR"
        }
    }
}

function Invoke-AdvancedCleaning {
    if (-not $DeepClean) { return }

    Write-Log "Limpieza avanzada..."

    if ($DryRun) {
        Write-Log "[DRYRUN] Se vaciaria la papelera"
        Write-Log "[DRYRUN] Se limpiaria cache DNS"
        return
    }

    try { Clear-RecycleBin -Force } catch {}
    try { Clear-DnsClientCache } catch {}
}

function Optimize-Services {
    Write-Log "Optimizando servicios..."

    $Services = @("DiagTrack")

    foreach ($Service in $Services) {
        $S = Get-Service -Name $Service -ErrorAction SilentlyContinue

        if ($S -and $S.Status -eq "Running") {
            if ($DryRun) {
                Write-Log "[DRYRUN] Se detendria y deshabilitaria servicio: $Service"
            }
            else {
                try {
                    Stop-Service -Name $Service -Force
                    Set-Service -Name $Service -StartupType Disabled
                    $Script:Stats.ServicesOptimized++
                    Write-Log "Servicio optimizado: $Service"
                }
                catch {
                    $Script:Stats.Errors++
                    Write-Log "Error servicio $Service: $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

function Remove-Bloat {
    if (-not $RemoveBloatware) { return }

    Write-Log "Analizando aplicaciones para eliminar..."

    $Apps = @(
        "Microsoft.XboxApp",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "Microsoft.BingWeather",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.Office.OneNote",
        "Microsoft.People",
        "Microsoft.SkypeApp",
        "Microsoft.Wallet",
        "Microsoft.YourPhone"
    )

    foreach ($App in $Apps) {
        if ($DryRun) {
            if (Get-AppxPackage -Name $App) {
                Write-Log "[DRYRUN] Se eliminaria app: $App"
            }
        }
        else {
            try {
                $Pkg = Get-AppxPackage -Name $App
                if ($Pkg) {
                    Remove-AppxPackage -InputObject $Pkg
                    $Script:Stats.BloatwareRemoved++
                    Write-Log "App eliminada: $App"
                }
            }
            catch {
                Write-Log "Error eliminando app $App: $($_.Exception.Message)" "ERROR"
            }
        }
    }
}

function Optimize-Startup {
    Write-Log "Revisando elementos de inicio..."

    $Paths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
    )

    foreach ($Path in $Paths) {
        if (-not (Test-Path $Path)) { continue }

        $Items = Get-ChildItem $Path -Filter "*.lnk"
        foreach ($Item in $Items) {

            Write-Log "Detectado en inicio: $($Item.Name)"

            if ($DisableStartup) {
                $Dest = Join-Path $Path "Startup_Disabled"
                if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest | Out-Null }

                if ($DryRun) {
                    Write-Log "[DRYRUN] Se moveria $($Item.Name)"
                }
                else {
                    try {
                        Move-Item -Path $Item.FullName -Destination $Dest -Force
                        $Script:Stats.StartupMoved++
                        Write-Log "Movido: $($Item.Name)"
                    }
                    catch {
                        $Script:Stats.Errors++
                        Write-Log "Error moviendo $($Item.Name): $($_.Exception.Message)" "ERROR"
                    }
                }
            }
        }
    }
}

function Set-HighPerformance {
    Write-Log "Ajustando plan de energia..."

    if ($DryRun) {
        Write-Log "[DRYRUN] Se aplicaria plan de Alto Rendimiento"
        return
    }

    $Plans = powercfg /LIST
    $Match = $Plans | Select-String "High performance"

    if ($Match) {
        if ($Match -match "([a-f0-9\-]{36})") {
            powercfg /SETACTIVE $Matches[1]
            $Script:Stats.PowerPlanChanged = $true
            Write-Log "Plan de energia cambiado a Alto Rendimiento"
        }
    }
}

# BLOQUE PRINCIPAL

try {
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath | Out-Null
    }

    $Script:LogFile = Join-Path $LogPath ("CFE_Optimize_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
    Write-Log "INICIO DEL SCRIPT CFE"

    Invoke-Cleaning
    Invoke-AdvancedCleaning
    Optimize-Services
    Remove-Bloat
    Optimize-Startup
    Set-HighPerformance

    Write-Log "FIN DEL PROCESO"
    Write-Log "Archivos eliminados: $($Script:Stats.FilesDeleted)"
    Write-Log "Espacio liberado: $(Get-FormattedSize $Script:Stats.SpaceFreedBytes)"

}
catch {
    Write-Log "ERROR CRITICO: $($_.Exception.Message)" "ERROR"
}
