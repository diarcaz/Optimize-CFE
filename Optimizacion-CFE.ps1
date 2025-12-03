<#
=========================================================
 OPTIMIZADOR CFE - SCRIPT DE MANTENIMIENTO (Arturo Sena)
 Version: Estable
=========================================================
#>

# Preferencias seguras
$ErrorActionPreference = "SilentlyContinue"

# Crear carpeta de logs
$Global:LogDir = "C:\CFE_Logs"
if (!(Test-Path $Global:LogDir)) {
    New-Item -ItemType Directory -Path $Global:LogDir | Out-Null
}

$Global:LogFile = Join-Path $Global:LogDir ("log_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt")

function Write-Log {
    param([string]$msg)
    Add-Content -Path $Global:LogFile -Value ("[" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "] " + $msg)
}

function Clear-UserTemp {
    Write-Host "Cleaning user temp..." -ForegroundColor Cyan
    Write-Log "Cleaning user temp..."
    $paths = @($env:TEMP, "$env:LOCALAPPDATA\Temp")
    foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ChildItem $p -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force
                    Write-Log "Deleted: $($_.FullName)"
                } catch {}
            }
        }
    }
    Write-Host "Done." -ForegroundColor Green
}

function Clear-AppCaches {
    Write-Host "Clearing app caches..." -ForegroundColor Cyan
    Write-Log "Clearing app caches..."

    $chrome = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
    $edge   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"

    foreach ($path in @($chrome, $edge)) {
        if (Test-Path $path) {
            try {
                Remove-Item "$path\*" -Force -Recurse
                Write-Log "Cleared cache: $path"
            } catch {}
        }
    }

    Write-Host "Done." -ForegroundColor Green
}

function Kill-BackgroundProcesses {
    Write-Host "Stopping background processes..." -ForegroundColor Cyan
    Write-Log "Killing background processes..."

    $targets = @(
        "OneDrive",
        "Teams",
        "SearchHost",
        "widget",
        "edgewebview",
        "outlook"
    )

    foreach ($proc in $targets) {
        Get-Process -Name $proc -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Stop-Process -Id $_.Id -Force
                Write-Log "Killed: $proc"
            } catch {}
        }
    }

    Write-Host "Done." -ForegroundColor Green
}

function Show-RAMUsage {
    Write-Host "Reading RAM usage..." -ForegroundColor Cyan
    $mem = Get-CimInstance -ClassName Win32_OperatingSystem
    $total = [math]::Round($mem.TotalVisibleMemorySize / 1024, 2)
    $free  = [math]::Round($mem.FreePhysicalMemory / 1024, 2)
    $used  = $total - $free

    Write-Host "Total RAM: $total MB"
    Write-Host "Used RAM : $used MB"
    Write-Host "Free RAM : $free MB"

    Write-Log "RAM usage: Total=$total Used=$used Free=$free"
}

function Show-SystemLoad {
    Write-Host "Checking system load..." -ForegroundColor Cyan
    $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
    $pc = [math]::Round($cpu.CounterSamples.CookedValue,2)

    Write-Host "CPU Load: $pc %"
    Write-Log "CPU Load: $pc %"
}

########## ADMIN MODULE ###########

function Clear-SystemTemp {
    Write-Host "Cleaning system temp..." -ForegroundColor Cyan
    Write-Log "Cleaning system temp..."

    $st = "C:\Windows\Temp"
    if (Test-Path $st) {
        Get-ChildItem $st -File -Recurse | ForEach-Object {
            try {
                Remove-Item $_.FullName -Force
                Write-Log "Deleted: $($_.FullName)"
            } catch {}
        }
    }
    Write-Host "Done." -ForegroundColor Green
}

function Flush-Recycle {
    Write-Host "Emptying recycle bin..." -ForegroundColor Cyan
    Write-Log "Emptying recycle bin..."
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    } catch {}
    Write-Host "Done." -ForegroundColor Green
}

function Flush-DNS {
    Write-Host "Flushing DNS..." -ForegroundColor Cyan
    Write-Log "Flushing DNS..."
    try {
        Clear-DnsClientCache
    } catch {}
    Write-Host "Done." -ForegroundColor Green
}

function Disable-Services {
    Write-Host "Disabling safe services..." -ForegroundColor Cyan
    Write-Log "Disabling SysMain, WSearch, DiagTrack..."

    $list = @("SysMain", "WSearch", "DiagTrack")

    foreach ($s in $list) {
        try {
            Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
            Set-Service  -Name $s -StartupType Disabled
            Write-Log "Disabled: $s"
        } catch {}
    }

    Write-Host "Done." -ForegroundColor Green
}

function Optimize-StartupItems {
    Write-Host "Optimizing startup..." -ForegroundColor Cyan
    Write-Log "Optimizing startup..."

    $paths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
    )

    foreach ($p in $paths) {
        if (Test-Path $p) {
            $disableDir = Join-Path $p "Disabled"
            if (!(Test-Path $disableDir)) {
                New-Item -ItemType Directory -Path $disableDir | Out-Null
            }

            Get-ChildItem $p -File -Filter "*.lnk" | ForEach-Object {
                try {
                    Move-Item $_.FullName $disableDir -Force
                    Write-Log "Moved startup item: $($_.Name)"
                } catch {}
            }
        }
    }

    Write-Host "Done." -ForegroundColor Green
}

function Set-HighPower {
    Write-Host "Setting high performance plan..." -ForegroundColor Cyan
    Write-Log "Setting high performance plan..."

    $plans = (powercfg /LIST)
    $hp = $plans | Select-String "High performance"

    if ($hp -match "([A-Fa-f0-9\-]{36})") {
        $guid = $Matches[1]
        powercfg /SETACTIVE $guid
        Write-Host "Plan activated." -ForegroundColor Green
        Write-Log "High performance plan activated."
    } else {
        Write-Host "Not found." -ForegroundColor Yellow
        Write-Log "High performance plan not found."
    }
}

# Detect admin
$IsAdmin = ([Security.Principal.WindowsPrincipal]
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

############################
### MAIN MENU LOOP
############################

do {
    Clear-Host
    Write-Host "========================================="
    Write-Host " OPTIMIZADOR CFE (Arturo Sena)"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "----- MODULE WITHOUT ADMIN -----"
    Write-Host "1) Clean user temp"
    Write-Host "2) Clear app caches (Chrome/Edge)"
    Write-Host "3) Kill background processes"
    Write-Host "4) Show RAM usage"
    Write-Host "5) Show system load"

    if ($IsAdmin) {
        Write-Host ""
        Write-Host "----- ADMIN MODULE -----"
        Write-Host "6) Clean system temp"
        Write-Host "7) Empty recycle bin"
        Write-Host "8) Flush DNS"
        Write-Host "9) Disable safe services"
        Write-Host "10) Optimize startup items"
        Write-Host "11) Enable high performance mode"
    }

    Write-Host ""
    Write-Host "0) Exit"
    Write-Host ""
    $opt = Read-Host "Select an option"

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

Write-Host "Exiting."
Write-Log "Script finished."

