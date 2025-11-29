<#
.SYNOPSIS
    Optimize-CFE.ps1 - Script de Optimización para estaciones administrativas (CFE - Zona Carmen)
.DESCRIPTION
    Limpieza por antigüedad en lotes, limpieza avanzada opcional, manejo seguro de accesos de inicio,
    intento de aplicar plan Alto Rendimiento, y registro detallado (UTF-8).
.PARAMETER DryRun
    Simulación (no hace cambios).
.PARAMETER DaysToKeep
    Días a conservar (por defecto 30).
.PARAMETER BatchSize
    Archivos por lote (por defecto 1000).
.PARAMETER DisableStartup
    Mueve accesos de inicio a subcarpeta Startup_Disabled.
.PARAMETER DeepClean
    Limpieza avanzada: Papelera + DNS.
.PARAMETER RemoveBloatware
    Intento de eliminación de apps de consumo (use con precaución).
.PARAMETER LogPath
    Carpeta para logs (por defecto C:\CFE_Logs).
.PARAMETER ShowConsoleSummary
    Muestra resumen en consola.
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

# --- Ajustes ---
$ErrorActionPreference = "Continue"    # evitar ocultar errores globalmente
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

function Get-FormattedSize {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "{0} Bytes" -f [int]$Bytes
}

function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "[$Timestamp] [$Type] $Message"
    if ($Script:LogFile) {
        # Asegurar que el archivo exista
        Add-Content -Path $Script:LogFile -Value $Line -Encoding UTF8
    }
    if ($Type -eq "ERROR") { Write-Host $Line -ForegroundColor Red }
    elseif ($VerbosePreference -ne 'SilentlyContinue') { Write-Host $Line -ForegroundColor Gray }
}

function Ensure-Log {
    param([string]$Folder)
    if (-not (Test-Path $Folder)) {
        try { New-Item -ItemType Directory -Path $Folder -Force | Out-Null } catch { throw "No se pudo crear carpeta de logs: $Folder" }
    }
    $fileName = "CFE_Optimize_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $Script:LogFile = Join-Path $Folder $fileName
    "" | Out-File -FilePath $Script:LogFile -Encoding UTF8
    Write-Log "Log inicializado: $Script:LogFile"
}

function Invoke-Cleaning {
    param([int]$Days, [int]$BatchSize)
    Write-Log "Iniciando limpieza: archivos con antigüedad mayor a $Days días..."
    $Targets = @(
        $env:TEMP,
        "$env:LOCALAPPDATA\Temp",
        "C:\Windows\Temp"
    )
    $Cutoff = (Get-Date).AddDays(-$Days)

    foreach ($Path in $Targets) {
        if (-not (Test-Path $Path)) {
            Write-Log "Ruta no encontrada: $Path" "WARN"
            continue
        }
        Write-Log "Escaneando: $Path"
        try {
            $files = @(Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $Cutoff })
            $count = $files.Count
            $sizeSum = ($files | Measure-Object -Property Length -Sum).Sum
            if (-not $sizeSum) { $sizeSum = 0 }

            Write-Log "Detectados $count archivos en $Path (aprox. $(Get-FormattedSize $sizeSum))"
            $Script:Stats.FilesDetected += $count

            if ($DryRun) {
                Write-Log "[DRYRUN] Listado (primeros 100) de archivos que se eliminarían en $Path:"
                $files | Select-Object FullName, LastWriteTime, @{Name='Size';Expression={Get-FormattedSize $_.Length}} | Select-Object -First 100 | ForEach-Object { Write-Log ("  " + $_.FullName) }
                continue
            }

            if ($count -eq 0) { continue }

            # Procesar por lotes
            $i = 0
            while ($i -lt $files.Count) {
                $end = [Math]::Min($i + $BatchSize - 1, $files.Count - 1)
                $batch = $files[$i..$end]
                Write-Log "Procesando lote de $($batch.Count) archivos en $Path"
                foreach ($f in $batch) {
                    try {
                        $size = $f.Length
                        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                        $Script:Stats.FilesDeleted++
                        $Script:Stats.SpaceFreedBytes += $size
                    } catch {
                        $Script:Stats.Errors++
                        Write-Log "Error eliminando $($f.FullName): $($_.Exception.Message)" "ERROR"
                    }
                }
                Start-Sleep -Milliseconds 150
                $i = $end + 1
            }

            # Intentar borrar carpetas vacías (seguro)
            try {
                $dirs = @(Get-ChildItem -Path $Path -Recurse -Directory -Force -ErrorAction SilentlyContinue)
                foreach ($d in $dirs) {
                    try {
                        if ((Get-ChildItem -Path $d.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0) {
                            Remove-Item -LiteralPath $d.FullName -Force -Recurse -ErrorAction Stop
                        }
                    } catch { }
                }
            } catch {}
        } catch {
            $Script:Stats.Errors++
            Write-Log "Error accediendo a $Path: $($_.Exception.Message)" "ERROR"
        }
    }
}

function Invoke-AdvancedCleaning {
    if (-not $DeepClean) { return }
    Write-Log "Limpieza avanzada iniciada..."
    if ($DryRun) { Write-Log "[DRYRUN] Se vaciaría la Papelera de Reciclaje y se limpiaría DNS." }
    else {
        try {
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-Log "Papelera vaciada."
        } catch {
            Write-Log "No se pudo vaciar papelera con Clear-RecycleBin, intentando fallback (puede requerir privilegios)." "WARN"
        }
        try {
            Clear-DnsClientCache -ErrorAction Stop
            Write-Log "Caché DNS limpiada."
        } catch {
            # fallback
            try { ipconfig /flushdns | Out-Null; Write-Log "Caché DNS limpiada con ipconfig /flushdns (fallback)." } catch { Write-Log "No se pudo limpiar caché DNS." "WARN" }
        }
    }
}

function Optimize-Services {
    Write-Log "Chequeando servicios recomendados para optimizar..."
    $services = @("DiagTrack")  # ejemplo seguro (telemetry)
    foreach ($s in $services) {
        try {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq 'Running') {
                if ($DryRun) { Write-Log "[DRYRUN] Se detendría y deshabilitaría servicio: $s" }
                else {
                    try {
                        Stop-Service -Name $s -Force -ErrorAction Stop
                        Set-Service -Name $s -StartupType Disabled -ErrorAction Stop
                        $Script:Stats.ServicesOptimized++
                        Write-Log "Servicio detenido y deshabilitado: $s"
                    } catch { Write-Log "Error gestionando servicio $s: $($_.Exception.Message)" "WARN" }
                }
            }
        } catch { Write-Log "Error consultando servicio $s: $($_.Exception.Message)" "WARN" }
    }
}

function Remove-Bloatware {
    if (-not $RemoveBloatware) { return }
    Write-Log "Iniciando intento de eliminación de bloatware (uso con precaución)."
    $apps = @(
        "Microsoft.XboxApp",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.Getstarted",
        "Microsoft.YourPhone"
    )
    foreach ($a in $apps) {
        try {
            $pkg = Get-AppxPackage -Name $a -ErrorAction SilentlyContinue
            if ($pkg) {
                if ($DryRun) { Write-Log "[DRYRUN] Se eliminaría paquete: $a" }
                else {
                    Get-AppxPackage -Name $a | Remove-AppxPackage -ErrorAction Stop
                    $Script:Stats.BloatwareRemoved++
                    Write-Log "Paquete eliminado: $a"
                }
            }
        } catch { Write-Log "No se pudo eliminar paquete $a: $($_.Exception.Message)" "WARN" }
    }
}

function Optimize-Startup {
    Write-Log "Analizando carpetas de inicio..."
    $StartupPaths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
    )
    foreach ($p in $StartupPaths) {
        if (-not (Test-Path $p)) { continue }
        try {
            $items = @(Get-ChildItem -Path $p -Filter "*.lnk" -File -Force -ErrorAction SilentlyContinue)
            if ($items.Count -gt 0) {
                Write-Log "Encontrados $($items.Count) accesos en $p"
                foreach ($it in $items) {
                    Write-Log "Detectado: $($it.Name)"
                    if ($DisableStartup) {
                        $disabled = Join-Path $p "Startup_Disabled"
                        if (-not (Test-Path $disabled)) { New-Item -Path $disabled -ItemType Directory -Force | Out-Null }
                        if ($DryRun) { Write-Log "[DRYRUN] Se movería $($it.Name) a $disabled" }
                        else {
                            try {
                                Move-Item -LiteralPath $it.FullName -Destination (Join-Path $disabled $it.Name) -Force -ErrorAction Stop
                                $Script:Stats.StartupMoved++
                            } catch { $Script:Stats.Errors++; Write-Log "Error moviendo $($it.Name): $($_.Exception.Message)" "ERROR" }
                        }
                    }
                }
            }
        } catch { Write-Log "Error en folder de inicio $p: $($_.Exception.Message)" "WARN" }
    }
}

function Set-HighPerformancePlan {
    Write-Log "Intentando aplicar plan de Alto Rendimiento..."
    if ($DryRun) { Write-Log "[DRYRUN] No se aplicará plan de energía." ; return }

    try {
        $out = (powercfg /LIST) 2>&1
        # Buscar GUIDs con etiqueta High performance o Alto rendimiento
        $matches = Select-String -InputObject $out -Pattern '([0-9A-Fa-f\-]{36}).*\((High performance|Alto rendimiento|Alto rendimiento \(Alto rendimiento\))\)' -AllMatches
        if ($matches.Count -gt 0) {
            $guid = ($matches.Matches | ForEach-Object { $_.Groups[1].Value })[0]
            cmd /c "powercfg /SETACTIVE $guid" | Out-Null
            $Script:Stats.PowerPlanChanged = $true
            Write-Log "Plan de energía cambiado a Alto Rendimiento ($guid)."
            return
        }

        # Fallback: GUID conocido (High performance)
        $fallback = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        $rc = cmd /c "powercfg /SETACTIVE $fallback" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $Script:Stats.PowerPlanChanged = $true
            Write-Log "Plan de energía cambiado (fallback) a GUID $fallback."
        } else {
            Write-Log "No se pudo aplicar plan de Alto Rendimiento (intente manualmente)." "WARN"
        }
    } catch {
        Write-Log "Error aplicando plan de energía: $($_.Exception.Message)" "ERROR"
    }
}

# --- EJECUCIÓN PRINCIPAL ---
try {
    Ensure-Log -Folder $LogPath

    Write-Log "Inicio del script - Usuario: $env:USERNAME - DryRun: $DryRun"

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { Write-Log "Advertencia: no ejecutado como Administrador. Algunas acciones pueden fallar." "WARN" }

    Invoke-Cleaning -Days $DaysToKeep -BatchSize $BatchSize
    Invoke-AdvancedCleaning
    Optimize-Services
    Remove-Bloatware
    Optimize-Startup
    Set-HighPerformancePlan

    # Resumen
    Write-Log "=== RESUMEN ==="
    Write-Log "Archivos detectados: $($Script:Stats.FilesDetected)"
    Write-Log "Archivos eliminados: $($Script:Stats.FilesDeleted)"
    Write-Log "Espacio liberado: $(Get-FormattedSize $Script:Stats.SpaceFreedBytes)"
    Write-Log "Servicios optimizados: $($Script:Stats.ServicesOptimized)"
    Write-Log "Bloatware eliminado: $($Script:Stats.BloatwareRemoved)"
    Write-Log "Accesos movidos: $($Script:Stats.StartupMoved)"
    Write-Log "Errores registrados: $($Script:Stats.Errors)"

    if ($ShowConsoleSummary) {
        Write-Host "`n=== RESUMEN ===" -ForegroundColor Cyan
        Write-Host "Modo: $([bool]$DryRun ? 'SIMULACIÓN' : 'EJECUCIÓN')" -ForegroundColor Yellow
        Write-Host "Archivos eliminados: $($Script:Stats.FilesDeleted)"
        Write-Host "Espacio liberado: $(Get-FormattedSize $Script:Stats.SpaceFreedBytes)"
        Write-Host "Accesos movidos: $($Script:Stats.StartupMoved)"
        Write-Host "Log guardado en: $Script:LogFile"
        Write-Host "==============================`n"
    }

} catch {
    Write-Log "Error crítico en script: $($_.Exception.Message)" "ERROR"
    Write-Error "Error crítico: $($_.Exception.Message)"
}
