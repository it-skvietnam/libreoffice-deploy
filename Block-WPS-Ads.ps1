# ============================================================
#  Block-WPS-Ads.ps1  v2.0
#  Chặn ads + bloatware + spyware của WPS Office trên Win 11
#  Yêu cầu: Chạy với quyền Administrator
# ============================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "SilentlyContinue"

function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "   [OK] $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "   [--] $msg" -ForegroundColor Yellow }

# ════════════════════════════════════════════════════════════
# 1. BLOCK DOMAINS (Ads + Telemetry + Spyware + Auto-update)
# ════════════════════════════════════════════════════════════

Write-Step "Cập nhật file hosts (ads + telemetry + spyware domains)..."

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$marker    = "# WPS-BLOCK-START"

$blockDomains = @(
    # Ads & marketing
    "ads.kingsoft.com", "mktres.wps.com", "activity.wps.com",
    "push.wps.com", "notice.wps.com", "coupon.wps.com", "mall.wps.com",

    # Telemetry & tracking (spyware)
    "stat.wps.com", "dc.wps.com", "wpstelemetry.com",
    "log.wps.com", "logser.wps.com", "collect.wps.com",
    "analytics.kingsoft.com", "data.wps.com", "tracker.wps.com",
    "telemetry.kingsoft.com", "report.wps.com", "monitor.wps.com",

    # Cloud sync & data upload
    "cloudfont.wps.com", "cloud.wps.com", "kbox.wps.com",
    "kdocs.cn", "wps.cn", "wpspush.com",

    # Update server (cài ngầm không hỏi)
    "update.wps.com", "upgrade.wps.com",
    "cdn-wps-online.cache.wpscdn.com",

    # KSafe / Kingsoft bloatware domains
    "ksafe.kingsoft.com", "duba.net", "ijinshan.com", "keniu.com"
)

$hostsContent = Get-Content $hostsPath -Raw
if ($hostsContent -match [regex]::Escape($marker)) {
    Write-Skip "Hosts da co WPS block, bo qua."
} else {
    $block = "`r`n$marker`r`n"
    foreach ($d in $blockDomains) { $block += "0.0.0.0 $d`r`n" }
    $block += "# WPS-BLOCK-END`r`n"
    Add-Content -Path $hostsPath -Value $block -Encoding UTF8
    Write-OK "Da block $($blockDomains.Count) domains."
}

ipconfig /flushdns | Out-Null
Write-OK "Flush DNS cache xong."

# ════════════════════════════════════════════════════════════
# 2. UNINSTALL BLOATWARE
# ════════════════════════════════════════════════════════════

Write-Step "Go cai dat bloatware di kem WPS..."

$regPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$bloatPatterns = @("*KSafe*", "*Duba*", "*Kingsoft*Internet*Security*", "*WPS*Cloud*")

foreach ($pattern in $bloatPatterns) {
    foreach ($regPath in $regPaths) {
        $apps = Get-ItemProperty $regPath -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $pattern }
        foreach ($app in $apps) {
            if ($app.UninstallString) {
                Write-Host "   Dang go: $($app.DisplayName)" -ForegroundColor Yellow
                $uninstStr = $app.UninstallString -replace '"',''
                Start-Process -FilePath $uninstStr -ArgumentList "/S /SILENT /quiet" -Wait -ErrorAction SilentlyContinue
                Write-OK "Da go: $($app.DisplayName)"
            }
        }
    }
}

# ════════════════════════════════════════════════════════════
# 3. KILL PROCESSES & DISABLE SERVICES
# ════════════════════════════════════════════════════════════

Write-Step "Kill cac process bloatware/spyware..."

$badProcs = @(
    "wpscloudsvr",   # WPS cloud service - upload file len server TQ
    "wpscenter",     # Ads/notification center
    "wpsupdate",     # Auto updater ngam
    "ksolaunch",     # Launcher cai them khong hoi
    "wps_sched",     # Scheduled tasks runner
    "ksafetray",     # KSafe system tray
    "ksafe",         # KSafe main (PUP/fake AV)
    "kxetray",       # Kingsoft tray
    "kwsmgr",        # Kingsoft Web Shield
    "kislive"        # Kingsoft Internet Security
)

foreach ($proc in $badProcs) {
    if (Get-Process -Name $proc -ErrorAction SilentlyContinue) {
        Stop-Process -Name $proc -Force
        Write-OK "Killed: $proc"
    }
}

Write-Step "Disable WPS/Kingsoft services..."

foreach ($pattern in @("WPSOffice*","KSafe*","Kingsoft*","Duba*")) {
    foreach ($svc in (Get-Service -Name $pattern -ErrorAction SilentlyContinue)) {
        if ($svc.Status -eq "Running") { Stop-Service $svc.Name -Force }
        Set-Service $svc.Name -StartupType Disabled
        Write-OK "Disabled service: $($svc.Name)"
    }
}

# ════════════════════════════════════════════════════════════
# 4. XOA SCHEDULED TASKS (tu cap nhat / cai lai ngam)
# ════════════════════════════════════════════════════════════

Write-Step "Xoa scheduled tasks cua WPS/Kingsoft..."

foreach ($pattern in @("*WPS*","*Kingsoft*","*KSafe*","*wpsupdate*")) {
    foreach ($task in (Get-ScheduledTask -TaskName $pattern -ErrorAction SilentlyContinue)) {
        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
        Write-OK "Xoa task: $($task.TaskName)"
    }
}

# ════════════════════════════════════════════════════════════
# 5. DON STARTUP ENTRIES
# ════════════════════════════════════════════════════════════

Write-Step "Don startup entries..."

$startupKeys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
)
$startupNames = @("WPS Office","WPSCENTER","wpscloudsvr","KSoLaunch","wps_sched","KSafeTray","kxetray","kwsmgr")

foreach ($key in $startupKeys) {
    if (Test-Path $key) {
        $entries = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        foreach ($name in $startupNames) {
            if ($entries.PSObject.Properties.Name -contains $name) {
                Remove-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue
                Write-OK "Xoa startup: $name"
            }
        }
    }
}

foreach ($folder in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
                       "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
    Get-ChildItem $folder -Filter "*.lnk" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "WPS|Kingsoft|KSafe" } |
    ForEach-Object { Remove-Item $_.FullName -Force; Write-OK "Xoa shortcut: $($_.Name)" }
}

# ════════════════════════════════════════════════════════════
# 6. WINDOWS FIREWALL - CHAN OUTBOUND
# ════════════════════════════════════════════════════════════

Write-Step "Them Windows Firewall rules chan WPS ket noi ra ngoai..."

$wpsBasePaths = @(
    "$env:ProgramFiles\Kingsoft\WPS Office",
    "${env:ProgramFiles(x86)}\Kingsoft\WPS Office",
    "$env:LOCALAPPDATA\Kingsoft\WPS Office"
)
$blockedExes = @("wpscloudsvr.exe","wpscenter.exe","wpsupdate.exe","ksolaunch.exe","ksafetray.exe","ksafe.exe")

foreach ($basePath in $wpsBasePaths) {
    if (Test-Path $basePath) {
        foreach ($exe in $blockedExes) {
            $found = Get-ChildItem -Path $basePath -Filter $exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                $ruleName = "BLOCK-WPS-$exe"
                Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
                New-NetFirewallRule -DisplayName $ruleName `
                    -Direction Outbound -Action Block `
                    -Program $found.FullName -Enabled True | Out-Null
                Write-OK "Firewall block: $($found.FullName)"
            }
        }
    }
}

# ════════════════════════════════════════════════════════════
# TONG KET
# ════════════════════════════════════════════════════════════

Write-Host "`n============================================" -ForegroundColor Magenta
Write-Host "  Hoan tat! WPS bloatware/spyware da bi chan." -ForegroundColor Magenta
Write-Host "============================================`n" -ForegroundColor Magenta
Write-Host "Da thuc hien:" -ForegroundColor White
Write-Host "  [1] Block $($blockDomains.Count) domains (ads/telemetry/spyware/cloud/update)" -ForegroundColor Gray
Write-Host "  [2] Go bloatware di kem (KSafe, Duba, Kingsoft Security...)" -ForegroundColor Gray
Write-Host "  [3] Kill & disable background services + processes" -ForegroundColor Gray
Write-Host "  [4] Xoa scheduled tasks tu cap nhat ngam" -ForegroundColor Gray
Write-Host "  [5] Don sach startup entries + shortcuts" -ForegroundColor Gray
Write-Host "  [6] Firewall outbound block cho process WPS" -ForegroundColor Gray
Write-Host "`nLuu y:" -ForegroundColor Yellow
Write-Host "  - WPS Writer/Calc/Impress van hoat dong offline binh thuong"
Write-Host "  - Chay lai script sau moi lan WPS tu update de re-apply"
Write-Host "  - Hoan tac: xoa dong giua # WPS-BLOCK-START va # WPS-BLOCK-END trong hosts"
Write-Host ""
