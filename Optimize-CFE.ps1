<#
.SYNOPSIS
    Script de Optimización de Estaciones de Trabajo en el Área de Finanzas (CFE – Zona Carmen)
    Proyecto: "Script de Optimización de Estaciones de Trabajo"
    Alumno: Arturo Enrique Martínez Sena
    
.DESCRIPTION
    Herramienta interna de mantenimiento preventivo para mejorar el rendimiento de las computadoras.
    Realiza limpieza de archivos temporales, optimización de inicio, ajustes de energía y limpieza avanzada opcional.
    Diseñado para ser seguro, no invasivo y 100% reversible.

.PARAMETER DryRun
    Si se especifica, simula las acciones sin realizar cambios reales (Modo Seguro).
    
.PARAMETER DaysToKeep
    Días de antigüedad para conservar archivos temporales. Por defecto: 30.
    
.PARAMETER BatchSize
    Número de archivos a procesar por lote para evitar saturación. Por defecto: 1000.
    
.PARAMETER DisableStartup
    Opcional. Si se especifica, mueve los accesos directos de inicio a una carpeta de respaldo.
    
.PARAMETER DeepClean
    Opcional. Realiza limpieza avanzada: Vacía Papelera de Reciclaje y Caché DNS.
    
.PARAMETER RemoveBloatware
    Opcional. Elimina aplicaciones preinstaladas de consumo (Xbox, Solitaire, Zune, etc.).
    
.PARAMETER LogPath
    Ruta donde se guardarán los registros. Por defecto: C:\CFE_Logs.
    
.PARAMETER ShowConsoleSummary
    Muestra un resumen final en la consola.

.EXAMPLE
    .\Optimize-CFE.ps1 -DryRun -ShowConsoleSummary
    Ejecuta en modo simulación y muestra resumen.

.EXAMPLE
    .\Optimize-CFE.ps1 -DeepClean -RemoveBloatware -LogPath "C:\Logs"
    Ejecuta optimización completa incluyendo limpieza profunda y bloatware.
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

# Configuración Global
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

# --- FUNCIONES ---

function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp] [$Type] $Message"
    
    # Escribir a archivo (UTF-8)
    if ($Script:LogFile) {
        Add-Content -Path $Script:LogFile -Value $LogLine -Encoding UTF8
    }
    
    # Mostrar en consola si es Verbose o Error
    if ($Type -eq "ERROR") {
        Write-Host $LogLine -ForegroundColor Red
    }
    elseif ($VerbosePreference -ne 'SilentlyContinue') {
        Write-Host $LogLine -ForegroundColor Gray
    }
}

function Get-FormattedSize {
    param([double]$Bytes)
    if ($Bytes -gt 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -gt 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -gt 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "{0} Bytes" -f $Bytes
}

function Invoke-Cleaning {
    Write-Log "Iniciando limpieza de archivos temporales (Antigüedad > $DaysToKeep días)..."
    
    $Targets = @(
        $env:TEMP,
        "$env:LOCALAPPDATA\Temp",
        "C:\Windows\Temp"
    )
    
    $CutoffDate = (Get-Date).AddDays(-$DaysToKeep)
    $BatchCounter = 0
    
    foreach ($Path in $Targets) {
        if (-not (Test-Path $Path)) { continue }
        
        Write-Log "Analizando ruta: $Path"
        
        try {
            $Files = Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue | 
            Where-Object { $_.LastWriteTime -lt $CutoffDate }
            
            foreach ($File in $Files) {
                $Script:Stats.FilesDetected++
                $Size = $File.Length
                
                if ($DryRun) {
                    Write-Log "[DRYRUN] Se eliminaría: $($File.FullName) ($(Get-FormattedSize $Size))"
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
                        Write-Log "Error al eliminar $($File.FullName): $($_.Exception.Message)" "ERROR"
                    }
                }
                
                # Control de lotes
                $BatchCounter++
                if ($BatchCounter -ge $BatchSize) {
                    Start-Sleep -Milliseconds 50 # Pausa para no saturar I/O
                    $BatchCounter = 0
                }
            }
        }
        catch {
            Write-Log "Error accediendo a $($Path): $($_.Exception.Message)" "ERROR"
        }
    }
}

function Invoke-AdvancedCleaning {
    if (-not $DeepClean) { return }
    Write-Log "Iniciando Limpieza Avanzada..."

    # 1. Vaciar Papelera
    if ($DryRun) {
        Write-Log "[DRYRUN] Se vaciaría la Papelera de Reciclaje."
    }
    else {
        try {
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-Log "Papelera de Reciclaje vaciada."
        }
        catch {
            Write-Log "Error al vaciar Papelera: $($_.Exception.Message)" "WARN"
        }
    }

    # 2. Limpiar Caché DNS
    if ($DryRun) {
        Write-Log "[DRYRUN] Se limpiaría la caché DNS."
    }
    else {
        try {
            Clear-DnsClientCache -ErrorAction Stop
            Write-Log "Caché DNS limpiada."
        }
        catch {
            Write-Log "Error al limpiar DNS: $($_.Exception.Message)" "WARN"
        }
    }
}

function Optimize-Services {
    Write-Log "Verificando servicios para optimización..."
    
    # Lista de servicios a optimizar (Telemetría básica)
    $Services = @("DiagTrack") 

    foreach ($ServiceName in $Services) {
        $Service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($Service -and $Service.Status -eq 'Running') {
            if ($DryRun) {
                Write-Log "[DRYRUN] Se detendría y deshabilitaría el servicio: $ServiceName"
            }
            else {
                try {
                    Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                    Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
                    $Script:Stats.ServicesOptimized++
                    Write-Log "Servicio optimizado (Detenido/Deshabilitado): $ServiceName"
                }
                catch {
                    Write-Log "Error al optimizar servicio $($ServiceName): $($_.Exception.Message)" "ERROR"
                }
            }
        }
    }
}

function Remove-Bloatware {
    if (-not $RemoveBloatware) { return }
    Write-Log "Analizando Bloatware (Apps de consumo)..."

    # Lista segura de apps a eliminar
    $BloatwareApps = @(
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

    foreach ($App in $BloatwareApps) {
        if ($DryRun) {
            $Package = Get-AppxPackage -Name $App -ErrorAction SilentlyContinue
            if ($Package) {
                Write-Log "[DRYRUN] Se eliminaría la aplicación: $App"
            }
        }
        else {
            try {
                $Package = Get-AppxPackage -Name $App -ErrorAction SilentlyContinue
                if ($Package) {
                    Get-AppxPackage -Name $App | Remove-AppxPackage -ErrorAction Stop
                    $Script:Stats.BloatwareRemoved++
                    Write-Log "Aplicación eliminada: $App"
                }
            }
            catch {
                Write-Log "Error al eliminar app $($App): $($_.Exception.Message)" "WARN"
            }
        }
    }
}

function Optimize-Startup {
    Write-Log "Analizando elementos de inicio..."
    
    $StartupPaths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
    )
    
    foreach ($Path in $StartupPaths) {
        if (Test-Path $Path) {
            $Items = Get-ChildItem -Path $Path -Filter "*.lnk"
            foreach ($Item in $Items) {
                Write-Log "Detectado en inicio: $($Item.Name)"
                
                if ($DisableStartup) {
                    $DisabledPath = Join-Path $Path "Startup_Disabled"
                    if (-not (Test-Path $DisabledPath)) {
                        New-Item -ItemType Directory -Path $DisabledPath -Force | Out-Null
                    }
                    
                    if ($DryRun) {
                        Write-Log "[DRYRUN] Se movería $($Item.Name) a $DisabledPath"
                    }
                    else {
                        try {
                            Move-Item -Path $Item.FullName -Destination $DisabledPath -Force -ErrorAction Stop
                            $Script:Stats.StartupMoved++
                            Write-Log "Movido $($Item.Name) a Startup_Disabled"
                        }
                        catch {
                            $Script:Stats.Errors++
                            Write-Log "Error al mover $($Item.Name): $($_.Exception.Message)" "ERROR"
                        }
                    }
                }
            }
        }
    }
}

function Set-HighPerformancePlan {
    Write-Log "Verificando planes de energía..."
    
    if ($DryRun) {
        Write-Log "[DRYRUN] Se intentaría aplicar el plan de Alto Rendimiento."
        return
    }
    
    try {
        $Plans = powercfg /LIST
        $HighPerf = $Plans | Select-String "Alto rendimiento|High performance"
        
        if ($HighPerf) {
            # Extraer GUID (asumiendo formato estándar de powercfg)
            if ($HighPerf -match 'GUID del plan de energía: ([a-f0-9\-]+)') {
                $Guid = $Matches[1]
                powercfg /SETACTIVE $Guid
                $Script:Stats.PowerPlanChanged = $true
                Write-Log "Plan de energía cambiado a Alto Rendimiento ($Guid)."
            }
        }
        else {
            Write-Log "Plan de Alto Rendimiento no encontrado. No se realizaron cambios." "WARN"
        }
    }
    catch {
        Write-Log "Error al gestionar energía: $($_.Exception.Message)" "ERROR"
    }
}

# --- BLOQUE PRINCIPAL ---

try {
    # 1. Inicialización
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    $LogFileName = "CFE_Optimize_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $Script:LogFile = Join-Path $LogPath $LogFileName
    
    Write-Log "=== INICIO DEL SCRIPT DE OPTIMIZACIÓN CFE (MEJORADO) ==="
    Write-Log "Usuario: $env:USERNAME"
    Write-Log "Modo DryRun: $DryRun"
    Write-Log "Opciones: DeepClean=$DeepClean, RemoveBloatware=$RemoveBloatware, DisableStartup=$DisableStartup"
    
    # 2. Verificación de Permisos
    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $IsAdmin) {
        Write-Log "ADVERTENCIA: El script no se está ejecutando como Administrador. Muchas optimizaciones fallarán." "WARN"
    }

    # 3. Ejecución de Tareas
    Invoke-Cleaning
    Invoke-AdvancedCleaning
    Optimize-Services
    Remove-Bloatware
    Optimize-Startup
    Set-HighPerformancePlan

    # 4. Resumen Final
    Write-Log "=== FIN DEL PROCESO ==="
    Write-Log "Archivos Detectados: $($Script:Stats.FilesDetected)"
    Write-Log "Archivos Eliminados: $($Script:Stats.FilesDeleted)"
    Write-Log "Espacio Liberado: $(Get-FormattedSize $Script:Stats.SpaceFreedBytes)"
    Write-Log "Servicios Optimizados: $($Script:Stats.ServicesOptimized)"
    Write-Log "Bloatware Eliminado: $($Script:Stats.BloatwareRemoved)"
    Write-Log "Errores: $($Script:Stats.Errors)"
    
    if ($ShowConsoleSummary) {
        Write-Host "`n=== RESUMEN DE OPTIMIZACIÓN ===" -ForegroundColor Cyan
        Write-Host "Modo: $(if($DryRun){'SIMULACIÓN'}else{'EJECUCIÓN'})" -ForegroundColor Yellow
        Write-Host "Archivos Eliminados: $($Script:Stats.FilesDeleted)"
        Write-Host "Espacio Liberado: $(Get-FormattedSize $Script:Stats.SpaceFreedBytes)"
        Write-Host "Servicios Optimizados: $($Script:Stats.ServicesOptimized)"
        Write-Host "Bloatware Eliminado: $($Script:Stats.BloatwareRemoved)"
        Write-Host "Errores: $($Script:Stats.Errors)"
        Write-Host "Log guardado en: $Script:LogFile"
        Write-Host "==============================`n"
    }

}
catch {
    Write-Error "Error crítico en el script: $($_.Exception.Message)"
}
