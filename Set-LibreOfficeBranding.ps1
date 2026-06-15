# Set-LibreOfficeBranding-fixed.ps1
# Requires running as Administrator
# LibreOffice Shortcut Branding — giả lập Office 365

# Metadata
# Run with: PowerShell -ExecutionPolicy Bypass -File Set-LibreOfficeBranding-fixed.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── CONFIG ────────────────────────────────────────────────────────────────────
$ICON_DIR   = "$env:ProgramFiles\LibreOffice\brand-icons"
$LO_PROGRAM = "$env:ProgramFiles\LibreOffice\program"
$START_MENU = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\LibreOffice"
$DESKTOP    = [Environment]::GetFolderPath('CommonDesktopDirectory')

# Chỉ Writer + Calc xuất hiện ngoài Desktop (tránh rác màn hình)
$DESKTOP_APPS = @('swriter.exe', 'scalc.exe')

# exe → Off (tên Office), Lo (tên LibreOffice), L (chữ icon),
#         CL (màu trái), CR (màu phải — tối hơn ~15%)
$APP_MAP = [ordered]@{
    'swriter.exe'  = @{ Off='Word';        Lo='LibreWriter';  L='W'; CL='#1A6BBD'; CR='#0D5099' }
    'scalc.exe'    = @{ Off='Excel';       Lo='LibreCalc';    L='X'; CL='#1E8049'; CR='#145230' }
    'simpress.exe' = @{ Off='PowerPoint';  Lo='LibreImpress'; L='P'; CL='#C43E1C'; CR='#8B2D13' }
    'sdraw.exe'    = @{ Off='Visio';       Lo='LibreDraw';    L='D'; CL='#3955A3'; CR='#2D4491' }
    'sbase.exe'    = @{ Off='Access';      Lo='LibreBase';    L='B'; CL='#A4373A'; CR='#7D292B' }
    'smath.exe'    = @{ Off='MathEditor';  Lo='LibreMath';    L='M'; CL='#5C6BC0'; CR='#3F51B5' }
}

# ── ICON GENERATION ───────────────────────────────────────────────────────────
Add-Type -AssemblyName System.Drawing

function ConvertFrom-HexColor([string]$hex) {
    $h = $hex.TrimStart('#')
    return [System.Drawing.Color]::FromArgb(
        255,
        [Convert]::ToInt32($h.Substring(0,2), 16),
        [Convert]::ToInt32($h.Substring(2,2), 16),
        [Convert]::ToInt32($h.Substring(4,2), 16)
    )
}

function New-IconBitmap {
    <#
    .DESCRIPTION
        Vẽ 1 bitmap icon với:
        - Nền split: nửa trái màu CL, nửa phải màu CR (tối hơn)
        - Chữ cái lớn canh giữa, màu trắng
        - Badge "L" hình tròn góc dưới phải (bỏ qua ở size 16px)
    #>
    param([int]$Size, [string]$Letter, [string]$ColorLeft, [string]$ColorRight)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $cL = ConvertFrom-HexColor $ColorLeft
    $cR = ConvertFrom-HexColor $ColorRight
    $r  = [int]($Size * 0.16)   # corner radius

    # Rounded rect path
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0,           0,           $r*2, $r*2, 180, 90)
    $path.AddArc($Size-$r*2,  0,           $r*2, $r*2, 270, 90)
    $path.AddArc($Size-$r*2,  $Size-$r*2, $r*2, $r*2,   0, 90)
    $path.AddArc(0,           $Size-$r*2, $r*2, $r*2,  90, 90)
    $path.CloseFigure()

    # Left fill
    $bL = New-Object System.Drawing.SolidBrush($cL)
    $g.FillPath($bL, $path)

    # Right fill clipped to half
    $bR = New-Object System.Drawing.SolidBrush($cR)
    $roundedRgn = New-Object System.Drawing.Region($path)
    $roundedRgn.Intersect([System.Drawing.RectangleF]::new([float]($Size / 2), 0.0, [float]$Size, [float]$Size))
    $g.SetClip($roundedRgn, [System.Drawing.Drawing2D.CombineMode]::Replace)
    $g.FillRectangle($bR, [float]($Size / 2), 0.0, [float]$Size, [float]$Size)
    $g.ResetClip()
    $roundedRgn.Dispose()

    # Main letter
    $letterPx = [float]($Size * 0.56)
    $lFont    = New-Object System.Drawing.Font('Segoe UI', $letterPx, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment     = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $wBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $letterRect = [System.Drawing.RectangleF]::new(0, -([float]($Size * 0.04)), [float]$Size, [float]$Size)
    $g.DrawString($Letter, $lFont, $wBrush, $letterRect, $sf)

    # Badge L
    if ($Size -ge 32) {
        $bs  = [int]($Size * 0.28)
        $bx  = $Size - $bs - [int]($Size * 0.04)
        $by  = $Size - $bs - [int]($Size * 0.04)
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(45, 0, 0, 0), [float]($Size * 0.012))

        $g.FillEllipse([System.Drawing.Brushes]::White, $bx, $by, $bs, $bs)
        $g.DrawEllipse($pen, $bx, $by, $bs, $bs)

        $bFont   = New-Object System.Drawing.Font('Segoe UI', [float]($bs * 0.54), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $loBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0x1D, 0x60, 0x96))
        $badgeRect = [System.Drawing.RectangleF]::new([float]$bx, [float]$by, [float]$bs, [float]$bs)
        $g.DrawString('L', $bFont, $loBrush, $badgeRect, $sf)

        $pen.Dispose()
        $bFont.Dispose()
        $loBrush.Dispose()
    }

    # Cleanup
    $g.Dispose()
    $path.Dispose()
    $bL.Dispose()
    $bR.Dispose()
    $lFont.Dispose()
    $wBrush.Dispose()
    $sf.Dispose()

    return $bmp
}

function Save-IcoFile {
    <#
    .DESCRIPTION
        Ghép nhiều PNG (256/48/32/16) vào 1 file .ico multi-resolution
    #>
    param([string]$OutputPath, [string]$Letter, [string]$CL, [string]$CR)

    $sizes   = @(256, 48, 32, 16)
    $streams = [System.Collections.Generic.List[System.IO.MemoryStream]]::new()

    foreach ($s in $sizes) {
        $bmp = New-IconBitmap -Size $s -Letter $Letter -ColorLeft $CL -ColorRight $CR
        $ms  = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $streams.Add($ms)
        $bmp.Dispose()
    }

    $ico = New-Object System.IO.MemoryStream
    $w   = New-Object System.IO.BinaryWriter($ico)

    # ICONDIR header
    $w.Write([uint16]0)
    $w.Write([uint16]1)
    $w.Write([uint16]$streams.Count)

    $dataOffset = 6 + ($streams.Count * 16)
    $cursor     = [uint32]$dataOffset

    for ($i = 0; $i -lt $streams.Count; $i++) {
        $dim = [byte]$(if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] })
        $w.Write([byte]$dim)
        $w.Write([byte]$dim)
        $w.Write([byte]0)
        $w.Write([byte]0)
        $w.Write([uint16]1)
        $w.Write([uint16]32)
        $w.Write([uint32]$streams[$i].Length)
        $w.Write([uint32]$cursor)
        $cursor += [uint32]$streams[$i].Length
    }

    foreach ($ms in $streams) { $w.Write($ms.ToArray()) }

    [System.IO.File]::WriteAllBytes($OutputPath, $ico.ToArray())

    $w.Dispose()
    $ico.Dispose()
    foreach ($ms in $streams) { $ms.Dispose() }
}

# ── SHORTCUT MANAGEMENT ───────────────────────────────────────────────────────
function Set-LnkShortcut {
    param(
        [string]$LnkPath,
        [string]$Target,
        [string]$IconPath,
        [string]$Description
    )
    $shell = New-Object -ComObject WScript.Shell
    try {
        $lnk   = $shell.CreateShortcut($LnkPath)
        $lnk.TargetPath       = $Target
        $lnk.IconLocation     = "$IconPath,0"
        $lnk.Description      = $Description
        $lnk.WorkingDirectory = Split-Path $Target -Parent
        $lnk.Save()
    } finally {
        if ($lnk) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($lnk) | Out-Null }
        if ($shell) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null }
    }
}

function Clear-IconCache {
    Write-Host '  Explorer restart de lam moi cache...' -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $cachePaths = @(
        "$env:LOCALAPPDATA\IconCache.db",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache_*.db"
    )
    foreach ($p in $cachePaths) {
        Remove-Item $p -Force -ErrorAction SilentlyContinue
    }
    Start-Process explorer
    Start-Sleep -Seconds 2
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
Write-Host "`n=== LibreOffice Brand Shortcut Script ===" -ForegroundColor Cyan

# Kiểm tra LO có cài không
if (-not (Test-Path $LO_PROGRAM)) {
    Write-Error "Khong tim thay LibreOffice tai '$LO_PROGRAM'. Kiem tra lai duong dan."
    exit 1
}

# Tạo thư mục cần thiết
foreach ($dir in @($ICON_DIR, $START_MENU)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

# ── Bước 1: Tạo icon ──────────────────────────────────────────────────────────
Write-Host "`n[1/3] Generating icons -> $ICON_DIR" -ForegroundColor Cyan

foreach ($exe in $APP_MAP.Keys) {
    $app      = $APP_MAP[$exe]
    $iconPath = Join-Path $ICON_DIR "$($app.Lo).ico"
    Write-Host "  $($app.Lo).ico " -NoNewline
    try {
        Save-IcoFile -OutputPath $iconPath -Letter $app.L -CL $app.CL -CR $app.CR
        Write-Host '[OK]' -ForegroundColor Green
    } catch {
        Write-Host '[FAIL]' -ForegroundColor Red
        Write-Warning "  $($_.Exception.Message)"
    }
}

# ── Bước 2: Xây lại shortcut ──────────────────────────────────────────────────
Write-Host "`n[2/3] Rebuilding shortcuts" -ForegroundColor Cyan

# Xóa hết shortcut cũ trong Start Menu LO
Get-ChildItem $START_MENU -Filter '*.lnk' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

foreach ($exe in $APP_MAP.Keys) {
    $app    = $APP_MAP[$exe]
    $target = Join-Path $LO_PROGRAM $exe

    if (-not (Test-Path $target)) {
        Write-Warning "  Khong tim thay $exe — bo qua"
        continue
    }

    $displayName = "$($app.Off) - $($app.Lo)"
    $iconPath    = Join-Path $ICON_DIR "$($app.Lo).ico"

    # Start Menu
    $lnkSM = Join-Path $START_MENU "$displayName.lnk"
    Set-LnkShortcut -LnkPath $lnkSM -Target $target -IconPath $iconPath -Description $displayName
    Write-Host "  [Start Menu] $displayName" -ForegroundColor Gray

    # Desktop (chỉ Writer + Calc)
    if ($exe -in $DESKTOP_APPS) {
        $lnkDT = Join-Path $DESKTOP "$displayName.lnk"
        Set-LnkShortcut -LnkPath $lnkDT -Target $target -IconPath $iconPath -Description $displayName
        Write-Host "  [Desktop]    $displayName" -ForegroundColor Gray
    }
}

# ── Bước 3: Làm mới icon cache ────────────────────────────────────────────────
Write-Host "`n[3/3] Refreshing icon cache" -ForegroundColor Cyan
Clear-IconCache

Write-Host "`nHoan tat! Neu icon van cu, restart may la du." -ForegroundColor Green
