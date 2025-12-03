<#
=========================================================
 OPTIMIZADOR CFE - VERSION CONSOLA (Seguro) - FIXED2
=========================================================
#>

$ErrorActionPreference = "SilentlyContinue"

# ==== Inicializar logs ====
$Global:LogDir = "C:\CFE_Logs"
if (!(Test-Path $Global:LogDir)) {
    New-Item -ItemType Directory -Path $Global:LogDir | Out-Null
}
$Global:LogFile = Join-Path $Global:LogDir ("log_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt")

function Write-Log { param([string]$msg)
    Add-Content -Path $Global:LogFile -Value ("[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "] " + $msg)
}

# ======================================================
#  =================  SEGURIDAD TOTAL ===================
# ======================================================

# Procesos NO críticos permitidos a cerrar
$SafeProcesses = @(
    "OneDrive",
    "SearchHost",
    "widget",
    "edgewebview"
)

# Servicios SEGURÍSIMOS de desactivar si el usuario lo permite
$SafeServices = @(
    "DiagTrack",        # Telemetría
    "WSearch"           # Indexado (No crítico)
)

# ======================================================
#  ================ FUNCIONES ===========================
# ======================================================

function Clear-UserTemp {
    Write-Host ""
    Write-Host "-> Limpiando TEMP de usuario..." -ForegroundColor Cyan
    Write-Log "Clean user temp"

    $paths = @($env:TEMP, "$env:LOCALAPPDATA\Temp")

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ChildItem $p -File -Recurse -ErrorAction SilentlyContinue | `
                ForEach-Object { try { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch { Write-Log ("Clear-UserTemp remove error: " + $_.Exception.Message) } }
        }
    }
    Write-Host "Done." -ForegroundColor Green
    Write-Log "Clear-UserTemp finished"
}

function Clear-AppCaches {
    Write-Host ""
    Write-Host "-> Limpiando caches de Chrome y Edge..." -ForegroundColor Cyan
    Write-Log "Clear app caches"

    $caches = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
    )

    foreach ($c in $caches) {
        if (Test-Path $c) {
            try { Remove-Item "$c\*" -Recurse -Force -ErrorAction SilentlyContinue; Write-Log ("Cleared cache: " + $c) } catch { Write-Log ("Clear-AppCaches error: " + $_.Exception.Message) }
        }
    }

    Write-Host "Done." -ForegroundColor Green
    Write-Log "Clear-AppCaches finished"
}

function Kill-BackgroundProcesses {
    Write-Host ""
    Write-Host "-> Finalizando procesos no criticos..." -ForegroundColor Cyan
    Write-Log "Kill safe processes"

    foreach ($p in $SafeProcesses) {
        $procs = Get-Process -Name $p -ErrorAction SilentlyContinue
        if ($procs) {
            foreach ($proc in $procs) {
                try {
                    Stop-Process $proc.Id -Force -ErrorAction SilentlyContinue
                    Write-Log ("Killed: " + $p + " (Id " + $proc.Id + ")")
                } catch {
                    Write-Log ("Failed to kill " + $p + ": " + $_.Exception.Message)
                }
            }
        }
    }

    Write-Host "Done." -ForegroundColor Green
    Write-Log "Kill-BackgroundProcesses finished"
}

function Show-RAMUsage {
    Write-Host ""
    Write-Host "-> Uso de RAM actual:" -ForegroundColor Cyan
    try {
        $mem = Get-CimInstance Win32_OperatingSystem
        $total = [math]::Round($mem.TotalVisibleMemorySize / 1024, 2)
        $free  = [math]::Round($mem.FreePhysicalMemory / 1024, 2)
        $used  = $total - $free

        Write-Host "RAM Total : $total MB"
        Write-Host "En uso   : $used MB"
        Write-Host "Libre    : $free MB"

        Write-Log ("RAM: total=" + $total + " used=" + $used + " free=" + $free)
    } catch {
        Write-Log ("Show-RAMUsage error: " + $_.Exception.Message)
    }
}

function Show-SystemLoad {
    Write-Host ""
    Write-Host "-> Carga de CPU..." -ForegroundColor Cyan
    try {
        $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
        $val = [math]::Round($cpu.CounterSamples.CookedValue,2)
        Write-Host "CPU: $val %"
        Write-Log ("CPU: " + $val + " %")
    } catch {
        Write-Log ("Show-SystemLoad error: " + $_.Exception.Message)
    }
}

function Clear-SystemTemp {
    Write-Host ""
    Write-Host "-> Limpiando TEMP del sistema..." -ForegroundColor Cyan
    Write-Log "Clean system temp"

    $st = "C:\Windows\Temp"
    if (Test-Path $st) {
        Get-ChildItem $st -File -Recurse -ErrorAction SilentlyContinue | `
            ForEach-Object { try { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue } catch { Write-Log ("Clear-SystemTemp remove error: " + $_.Exception.Message) } }
    }
    Write-Host "Done." -ForegroundColor Green
    Write-Log "Clear-SystemTemp finished"
}

function Flush-Recycle {
    Write-Host ""
    Write-Host "-> Vaciando papelera..." -ForegroundColor Cyan
    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Log "Flush-Recycle success" } catch { Write-Log ("Flush-Recycle error: " + $_.Exception.Message) }
    Write-Host "Done." -ForegroundColor Green
    Write-Log "Flush-Recycle finished"
}

function Flush-DNS {
    Write-Host ""
    Write-Host "-> Limpiando cache DNS..." -ForegroundColor Cyan
    try { Clear-DnsClientCache -ErrorAction SilentlyContinue; Write-Log "Flush-DNS success" } catch { Write-Log ("Flush-DNS error: " + $_.Exception.Message) }
    Write-Host "Done." -ForegroundColor Green
    Write-Log "Flush-DNS finished"
}

function Disable-Services {
    Write-Host ""
    Write-Host "-> Desactivando servicios seguros..." -ForegroundColor Cyan
    foreach ($s in $SafeServices) {
        try {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -ne 'Stopped') {
                Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
            }
            Set-Service  -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log ("Disabled: " + $s)
        } catch {
            Write-Log ("Disable-Services error for " + $s + ": " + $_.Exception.Message)
        }
    }
    Write-Host "Done." -ForegroundColor Green
    Write-Log "Disable-Services finished"
}

function Optimize-StartupItems {
    Write-Host ""
    Write-Host "-> Optimizando elementos de inicio..." -ForegroundColor Cyan

    # Solo deshabilitamos accesos directos, nunca archivos ejecutables reales
    $startupPaths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
    )

    foreach ($p in $startupPaths) {
        if (Test-Path $p) {
            $disableDir = Join-Path $p "Disabled"
            if (!(Test-Path $disableDir)) { New-Item -ItemType Directory -Path $disableDir | Out-Null }
            Get-ChildItem $p -File -Filter "*.lnk" | ForEach-Object {
                try {
                    Move-Item $_.FullName $disableDir -Force -ErrorAction SilentlyContinue
                    Write-Log ("Moved startup item: " + $_.Name)
                } catch {
                    Write-Log ("Optimize-StartupItems error: " + $_.Exception.Message)
                }
            }
        }
    }

    Write-Host "Done." -ForegroundColor Green
    Write-Log "Optimize-StartupItems finished"
}

function Set-HighPower {
    Write-Host ""
    Write-Host "-> Activando plan de alto rendimiento..." -ForegroundColor Cyan

    $plans = powercfg /LIST
    $hp = $plans | Select-String "High performance"

    try {
        if ($hp -match "([A-Fa-f0-9\-]{36})") {
            powercfg /SETACTIVE $Matches[1]
            Write-Host "Activated." -ForegroundColor Green
            Write-Log "High performance plan activated"
        } else {
            Write-Host "Not found." -ForegroundColor Yellow
            Write-Log "High performance plan not found"
        }
    } catch {
        Write-Log ("Set-HighPower error: " + $_.Exception.Message)
    }
}

# Detectar admin (forma segura y parseable)
$IsAdmin = ([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ======================================================
#  ================ MENU ================================
# ======================================================

do {
    Clear-Host
    Write-Host "========================================="
    Write-Host " OPTIMIZADOR CFE - CONSOLA"
    Write-Host "========================================="

    Write-Host ""
    Write-Host "--- MODULO SEGURO (SIN ADMIN) ---"
    Write-Host "1) Limpiar temp usuario"
    Write-Host "2) Limpiar caches navegador"
    Write-Host "3) Finalizar procesos seguros"
    Write-Host "4) Mostrar uso RAM"
    Write-Host "5) Mostrar carga CPU"

    if ($IsAdmin) {
        Write-Host ""
        Write-Host "--- MODULO ADMIN ---"
        Write-Host "6) Limpiar temp sistema"
        Write-Host "7) Vaciar papelera"
        Write-Host "8) Flush DNS"
        Write-Host "9) Desactivar servicios no criticos"
        Write-Host "10) Optimizar inicio"
        Write-Host "11) Alto rendimiento"
    }

    Write-Host ""
    Write-Host "0) Salir"
    $opt = Read-Host "`nSelecciona una opcion"

    switch ($opt) {
        "1" { Clear-UserTemp }
        "2" { Clear-AppCaches }
        "3" { Kill-BackgroundProcesses }
        "4" { Show-RAMUsage }
        "5" { Show-SystemLoad }
        "6" { if ($IsAdmin) { Clear-SystemTemp } }
        "7" { if ($IsAdmin) { Flush-Recycle } }
        "8" { if ($IsAdmin) { Flush-DNS } }
        "9" { if ($IsAdmin) { Disable-Services } }
        "10" { if ($IsAdmin) { Optimize-StartupItems } }
        "11" { if ($IsAdmin) { Set-HighPower } }
        "0" { break }
    }

    Write-Host ""
    Pause

} while ($opt -ne "0")

Write-Log "Script finished."
Write-Host "Saliendo..."
[void][System.Console]::ReadLine()
