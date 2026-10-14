[CmdletBinding()]
param(
    [string] $BlueStacksDir = 'C:\Program Files\BlueStacks_nxt',

    [ValidateRange(1, 168)]
    [double] $IntervalHours = 1,

    [ValidatePattern('^\d+x\d+$')]
    [Alias('WindowSize')]
    [string] $ScreenSize = '1080x1920',

    [ValidatePattern('^\d+x\d+$')]
    [Alias('Click-1')]
    [string] $Click1 = '1009x1520',

    [ValidatePattern('^\d+x\d+$')]
    [Alias('Click-2')]
    [string] $Click2 = '114x1821',

    [ValidatePattern('^\d+x\d+$')]
    [Alias('Click-3')]
    [string] $Click3 = '540x1580',

    [ValidateRange(30, 900)]
    [int] $GameStartupTimeoutSeconds = 180,

    [ValidateRange(1, 30)]
    [int] $PollIntervalSeconds = 5
)

$ErrorActionPreference = 'Stop'

$Adb = Join-Path $BlueStacksDir 'HD-Adb.exe'
$Player = Join-Path $BlueStacksDir 'HD-Player.exe'
$GamePackage = 'com.camelgames.superking'
$ClickLabels = @(
    'Monster Menu Button',
    'World/Castle View Button',
    'Auto Monster Start Button'
)

function Convert-ClickPoint([string] $Value, [string] $Name) {
    if ($Value -notmatch '^(\d+)x(\d+)$') {
        throw "$Name must use the format WIDTHxHEIGHT, for example 1009x1520."
    }
    return @{ X = [int]$Matches[1]; Y = [int]$Matches[2] }
}

function Invoke-Adb([string[]] $Arguments) {
    & $script:Adb @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "ADB command failed: $($Arguments -join ' ')"
    }
}

function Wait-ForGameForeground {
    $deadline = (Get-Date).AddSeconds($script:GameStartupTimeoutSeconds)
    $packagePattern = [regex]::Escape($script:GamePackage)
    $foregroundPattern = '(?im)(?:mResumedActivity|topResumedActivity)\s*[:=][^\r\n]*' + $packagePattern
    $lastForegroundLine = '(no resumed activity line found)'

    Write-Host "Waiting for War and Order to appear in the foreground (checking every $($script:PollIntervalSeconds) seconds; timeout $($script:GameStartupTimeoutSeconds) seconds)..."
    while ((Get-Date) -lt $deadline) {
        $activityLines = & $script:Adb shell dumpsys activity activities 2>&1
        if ($LASTEXITCODE -eq 0) {
            $activityDump = $activityLines -join "`n"
            $lastForeground = $activityDump -split "`n" | Where-Object { $_ -match '(?i)(mResumedActivity|topResumedActivity)' } | Select-Object -Last 1
            if ($lastForeground) { $lastForegroundLine = $lastForeground.Trim() }
            if ($activityDump -match $foregroundPattern) {
                Write-Host 'War and Order is reported as the foreground Android activity.'
                return
            }
        }
        Start-Sleep -Seconds $script:PollIntervalSeconds
    }

    throw "War and Order did not appear in the foreground within $($script:GameStartupTimeoutSeconds) seconds. Stopping before taps. Last activity status: $lastForegroundLine"
}

if (-not (Test-Path -LiteralPath $Adb)) {
    throw "BlueStacks ADB was not found at '$Adb'. Update BlueStacksDir in this script if your install path differs."
}
if (-not (Test-Path -LiteralPath $Player)) {
    throw "BlueStacks player was not found at '$Player'. Update BlueStacksDir in this script if your install path differs."
}

$screenParts = $ScreenSize -split 'x'
$screenWidth = [int]$screenParts[0]
$screenHeight = [int]$screenParts[1]
$clickPoints = @(
    (Convert-ClickPoint $Click1 'Click1'),
    (Convert-ClickPoint $Click2 'Click2'),
    (Convert-ClickPoint $Click3 'Click3')
)
foreach ($point in $clickPoints) {
    if ($point.X -ge $screenWidth -or $point.Y -ge $screenHeight) {
        throw "Click ($($point.X),$($point.Y)) is outside screen size $ScreenSize."
    }
}

# Start BlueStacks if it is not already open.
$startedBlueStacks = $false
if (-not (Get-Process -Name 'HD-Player' -ErrorAction SilentlyContinue)) {
    Write-Host 'Starting BlueStacks...'
    Start-Process -FilePath $Player
    $startedBlueStacks = $true
}

# Wait for the BlueStacks Android instance to become available through ADB.
Write-Host 'Waiting for the BlueStacks Android device...'
$deadline = (Get-Date).AddMinutes(3)
$deviceReady = $false
while ((Get-Date) -lt $deadline) {
    $deviceOutput = & $Adb devices 2>&1
    $deviceReady = [bool]($deviceOutput | Where-Object { $_ -match '^emulator-\d+\s+device$' })
    if ($deviceReady) { break }
    Start-Sleep -Seconds 2
}
if (-not $deviceReady) {
    throw 'No ready BlueStacks emulator appeared within 3 minutes. Enable Android Debug Bridge in BlueStacks Settings > Advanced.'
}

# Set the Android coordinate space and verify it before any taps.
Invoke-Adb @('shell', 'wm', 'size', $ScreenSize)
Start-Sleep -Seconds 2
$reportedSize = (& $Adb shell wm size 2>&1) -join ' '
if ($LASTEXITCODE -ne 0 -or $reportedSize -notmatch [regex]::Escape($ScreenSize)) {
    throw "Could not verify screen size '$ScreenSize'. ADB reported: $reportedSize"
}
Write-Host "Android screen size set to $ScreenSize."

# Confirm the configured game package is installed.
$installedPackage = (& $Adb shell pm list packages $GamePackage 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0 -or $installedPackage -notmatch [regex]::Escape("package:$GamePackage")) {
    throw "Game package '$GamePackage' was not found. Find it with: HD-Adb.exe shell pm list packages | findstr /i camel"
}

Write-Host "Repeating every $IntervalHours hour(s). Press Ctrl+C to stop."
Write-Host "Click points: $($ClickLabels[0]) $Click1, $($ClickLabels[1]) $Click2, $($ClickLabels[2]) $Click3"

$firstCycle = $true
while ($true) {
    # Reapply and verify resolution each cycle in case BlueStacks reset it.
    Invoke-Adb @('shell', 'wm', 'size', $ScreenSize)
    $reportedSize = (& $Adb shell wm size 2>&1) -join ' '
    if ($LASTEXITCODE -ne 0 -or $reportedSize -notmatch [regex]::Escape($ScreenSize)) {
        throw "Screen size check failed; stopping before taps. ADB reported: $reportedSize"
    }

    # Launch (or bring forward) the game, then poll until Android reports it foreground.
    Invoke-Adb @('shell', 'monkey', '-p', $GamePackage, '-c', 'android.intent.category.LAUNCHER', '1')
    Wait-ForGameForeground

    if ($firstCycle -and $startedBlueStacks) {
        Write-Host ''
        Write-Host 'Close any game splash screens, promotions, or purchase screens before continuing.' -ForegroundColor DarkYellow
        Write-Host 'When the normal game screen is visible, press any key to continue.' -ForegroundColor DarkYellow -NoNewline
        [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        Write-Host ''
        $point = $clickPoints[1]
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Startup click: $($ClickLabels[1]) ($($point.X), $($point.Y))"
        Invoke-Adb @('shell', 'input', 'tap', [string]$point.X, [string]$point.Y)
        Write-Host 'Waiting 10 seconds before clicking Monster Menu Button...'
        Start-Sleep -Seconds 10
    }
    elseif ($firstCycle) {
        Write-Host 'Change to World/Castle View. Press any key when ready to start' -ForegroundColor DarkYellow
        [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }

    for ($i = 0; $i -lt $clickPoints.Count; $i++) {
        $point = $clickPoints[$i]
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Clicking $($ClickLabels[$i]): ($($point.X), $($point.Y))"
        Invoke-Adb @('shell', 'input', 'tap', [string]$point.X, [string]$point.Y)
        if ($i -eq 0) {
            Write-Host 'Waiting 3 seconds before clicking World/Castle View Button...'
            Start-Sleep -Seconds 3
        }
    }

    $firstCycle = $false
    $startedBlueStacks = $false
    $finishedAt = Get-Date
    Write-Host "[$($finishedAt.ToString('yyyy-MM-dd HH:mm:ss'))] Cycle finished. Waiting $IntervalHours hour(s) before the next cycle."
    Start-Sleep -Milliseconds ([int64]($IntervalHours * 3600000))
}
