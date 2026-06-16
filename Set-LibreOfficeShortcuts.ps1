#Requires -RunAsAdministrator
# LibreOffice Shortcut Renaming
# Chay: PowerShell -ExecutionPolicy Bypass -File Set-LibreOfficeShortcuts.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- CONFIG ---
$DESKTOP_APPS = @('swriter.exe', 'scalc.exe')

$APP_MAP = [ordered]@{
    'swriter.exe'  = @{ Off = 'Word';       Lo = 'LibreWriter'  }
    'scalc.exe'    = @{ Off = 'Excel';      Lo = 'LibreCalc'    }
    'simpress.exe' = @{ Off = 'PowerPoint'; Lo = 'LibreImpress' }
    'sdraw.exe'    = @{ Off = 'Visio';      Lo = 'LibreDraw'    }
    'sbase.exe'    = @{ Off = 'Access';     Lo = 'LibreBase'    }
    'smath.exe'    = @{ Off = 'Formula';    Lo = 'LibreMath'    }
}

$START_MENU = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\LibreOffice'
$DESKTOP    = [Environment]::GetFolderPath('CommonDesktopDirectory')

# --- FALLBACK: Tim duong dan LibreOffice ---
function Find-LibreOfficePath {

    # Tang 1: Cac duong dan pho bien
    $candidates = @()
    $pf64 = $env:ProgramFiles
    if ($pf64) {
        $candidates += Join-Path $pf64 'LibreOffice\program'
        $candidates += Join-Path $pf64 'LibreOffice 7\program'
        $candidates += Join-Path $pf64 'LibreOffice 24\program'
    }
    $pf86 = ${env:ProgramFiles(x86)}
    if ($pf86) {
        $candidates += Join-Path $pf86 'LibreOffice\program'
        $candidates += Join-Path $pf86 'LibreOffice 7\program'
    }

    foreach ($p in $candidates) {
        if (Test-Path (Join-Path $p 'swriter.exe')) {
            return $p
        }
    }

    # Tang 2: Registry
    $regRoots = @(
        'HKLM:\SOFTWARE\LibreOffice'
        'HKLM:\SOFTWARE\WOW6432Node\LibreOffice'
    )
    foreach ($reg in $regRoots) {
        if (-not (Test-Path $reg)) { continue }
        $subkeys = Get-ChildItem $reg -ErrorAction SilentlyContinue
        foreach ($key in $subkeys) {
            $subkeys2 = Get-ChildItem $key.PSPath -ErrorAction SilentlyContinue
            foreach ($key2 in $subkeys2) {
                $props = Get-ItemProperty -Path $key2.PSPath -ErrorAction SilentlyContinue
                if (-not $props) { continue }
                $pathProp = $props.PSObject.Properties['Path']
                if (-not $pathProp) { continue }
                $installPath = $pathProp.Value
                if (-not $installPath) { continue }
                $programPath = Join-Path $installPath 'program'
                if (Test-Path (Join-Path $programPath 'swriter.exe')) {
                    return $programPath
                }
            }
        }
    }

    # Tang 3: Quet cac o dia thuc su ton tai tren may
    $activeDrives = (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue).Root
    $subDirs = @('LibreOffice', 'LibreOffice 7', 'LibreOffice 24')
    $roots   = @('Program Files', 'Program Files (x86)')

    foreach ($drive in $activeDrives) {
        foreach ($root in $roots) {
            foreach ($sub in $subDirs) {
                $p = Join-Path $drive "${root}\${sub}\program"
                $swriter = Join-Path $p 'swriter.exe'
                if (Test-Path $swriter -ErrorAction SilentlyContinue) {
                    return $p
                }
            }
        }
    }

    return $null
}

# --- DIALOG: Hop thoai chon thu cong ---
function Show-FolderDialog {
    Add-Type -AssemblyName System.Windows.Forms

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Khong tim thay LibreOffice tu dong. Chon thu muc "program" cua LibreOffice (vi du: C:\Program Files\LibreOffice\program)'
    $dialog.ShowNewFolderButton = $false

    $result = $dialog.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selected = $dialog.SelectedPath
        if (Test-Path (Join-Path $selected 'swriter.exe')) {
            return $selected
        }
        [System.Windows.Forms.MessageBox]::Show(
            "Thu muc ban chon khong chua swriter.exe.`nVui long chon dung thu muc 'program' ben trong thu muc cai dat LibreOffice.",
            'Sai thu muc',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }

    return $null
}

# --- SHORTCUT ---
function Set-LnkShortcut {
    param(
        [string]$LnkPath,
        [string]$Target,
        [string]$DisplayName
    )
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($LnkPath)
    $lnk.TargetPath = $Target
    $lnk.Description = $DisplayName
    $lnk.WorkingDirectory = Split-Path $Target -Parent
    $lnk.Save()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($lnk) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
}

# --- MAIN ---
Write-Host '=== LibreOffice Shortcut Renaming ===' -ForegroundColor Cyan

Write-Host 'Tim duong dan LibreOffice...' -ForegroundColor Cyan
$LO_PROGRAM = Find-LibreOfficePath

if ($LO_PROGRAM) {
    Write-Host "  [OK] Tim thay tai: $LO_PROGRAM" -ForegroundColor Green
} else {
    Write-Warning 'Khong tim thay LibreOffice o cac vi tri mac dinh, registry va cac o dia hien co.'
    Write-Host '  -> Mo hop thoai chon thu cong...' -ForegroundColor Yellow

    $LO_PROGRAM = Show-FolderDialog

    if (-not $LO_PROGRAM) {
        Write-Host '[ABORT] Huy hoac chon sai thu muc. Thoat.' -ForegroundColor Red
        exit 1
    }

    Write-Host "  [OK] Su dung duong dan: $LO_PROGRAM" -ForegroundColor Green
}

if (-not (Test-Path $START_MENU)) {
    New-Item -ItemType Directory -Path $START_MENU | Out-Null
}

# Buoc 1: Xoa shortcut cu
Write-Host '[1/2] Xoa shortcut cu...' -ForegroundColor Cyan

Get-ChildItem -Path $START_MENU -Filter '*.lnk' -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
    Write-Host "  Removed: $($_.Name)" -ForegroundColor DarkGray
}

# Buoc 2: Tao shortcut moi
Write-Host '[2/2] Tao shortcut moi...' -ForegroundColor Cyan

foreach ($exe in $APP_MAP.Keys) {
    $app = $APP_MAP[$exe]
    $target = Join-Path $LO_PROGRAM $exe

    if (-not (Test-Path $target)) {
        Write-Warning "Khong tim thay $exe - bo qua"
        continue
    }

    $displayName = "$($app.Off) - $($app.Lo)"

    try {
        $lnkSM = Join-Path $START_MENU "$displayName.lnk"
        Set-LnkShortcut -LnkPath $lnkSM -Target $target -DisplayName $displayName
        Write-Host "  [Start Menu] $displayName" -ForegroundColor Gray
    } catch {
        Write-Warning "  Loi Start Menu $($displayName): $($_.Exception.Message)"
    }

    if ($exe -in $DESKTOP_APPS) {
        try {
            $lnkDT = Join-Path $DESKTOP "$displayName.lnk"
            Set-LnkShortcut -LnkPath $lnkDT -Target $target -DisplayName $displayName
            Write-Host "  [Desktop]    $displayName" -ForegroundColor Gray
        } catch {
            Write-Warning "  Loi Desktop $($displayName): $($_.Exception.Message)"
        }
    }
}

Write-Host 'Hoan tat!' -ForegroundColor Green
