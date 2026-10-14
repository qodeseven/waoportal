[CmdletBinding()]
param(
    [string] $BlueStacksDir = 'C:\Program Files\BlueStacks_nxt',

    [ValidateRange(0.0167, 168)]
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
    [int] $PollIntervalSeconds = 5,

    [Alias('v')]
    [switch] $VerboseOutput
)

$ErrorActionPreference = 'Stop'
$script:VerboseOutput = [bool]$VerboseOutput

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

function Invoke-Adb([string[]] $Arguments, [switch] $CaptureOutput) {
    # Windows PowerShell 5.1 promotes native stderr to ErrorRecord objects.
    # HD-Adb.exe writes harmless diagnostics there even when a command succeeds,
    # so use Continue only for this native invocation and capture both streams.
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $adbOutput = @(& $script:Adb @Arguments 2>&1)
        $adbExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($adbExitCode -ne 0) {
        $details = ''
        if ($adbOutput) {
            $details = "`n" + ($adbOutput -join [Environment]::NewLine)
        }
        throw "ADB command failed with exit code ${adbExitCode}: $($Arguments -join ' ')$details"
    }
    if ($script:VerboseOutput -and $adbOutput) {
        Write-Host ($adbOutput -join [Environment]::NewLine)
    }
    if ($CaptureOutput) { return $adbOutput }
}

function Confirm-YesByDefault([string] $Prompt) {
    while ($true) {
        $response = Read-Host "$Prompt [Y/n]"
        if ([string]::IsNullOrWhiteSpace($response)) {
            return $true
        }

        switch ($response.Trim().ToLowerInvariant()) {
            'y' { return $true }
            'yes' { return $true }
            'n' { return $false }
            'no' { return $false }
            default { Write-Host 'Please enter Y or N.' -ForegroundColor Yellow }
        }
    }
}

function Wait-ForGameForeground {
    $deadline = (Get-Date).AddSeconds($script:GameStartupTimeoutSeconds)
    $packagePattern = [regex]::Escape($script:GamePackage)
    $foregroundPattern = '(?im)(?:mResumedActivity|topResumedActivity)\s*[:=][^\r\n]*' + $packagePattern
    $lastForegroundLine = '(no resumed activity line found)'

    Write-Host "Waiting for War and Order to appear in the foreground (checking every $($script:PollIntervalSeconds) seconds; timeout $($script:GameStartupTimeoutSeconds) seconds)..."
    while ((Get-Date) -lt $deadline) {
        $activityLines = Invoke-Adb @('shell', 'dumpsys', 'activity', 'activities') -CaptureOutput
        $activityDump = $activityLines -join "`n"
        $lastForeground = $activityDump -split "`n" | Where-Object { $_ -match '(?i)(mResumedActivity|topResumedActivity)' } | Select-Object -Last 1
        if ($lastForeground) { $lastForegroundLine = $lastForeground.Trim() }
        if ($activityDump -match $foregroundPattern) {
            Write-Host 'War and Order is reported as the foreground Android activity.'
            return
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
    $deviceOutput = Invoke-Adb @('devices') -CaptureOutput
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
$reportedSize = (Invoke-Adb @('shell', 'wm', 'size') -CaptureOutput | Out-String)
if ($reportedSize -notmatch [regex]::Escape($ScreenSize)) {
    throw "Could not verify screen size '$ScreenSize'. ADB reported: $reportedSize"
}
Write-Host "Android screen size set to $ScreenSize."

# Confirm the configured game package is installed.
$installedPackage = (Invoke-Adb @('shell', 'pm', 'list', 'packages', $GamePackage) -CaptureOutput | Out-String)
if ($installedPackage -notmatch [regex]::Escape("package:$GamePackage")) {
    throw "Game package '$GamePackage' was not found. Find it with: HD-Adb.exe shell pm list packages | findstr /i camel"
}

Write-Host "Repeating every $IntervalHours hour(s). Press Ctrl+C to stop."
Write-Host "Click points: $($ClickLabels[0]) $Click1, $($ClickLabels[1]) $Click2, $($ClickLabels[2]) $Click3"

$firstCycle = $true
while ($true) {
    # Reapply and verify resolution each cycle in case BlueStacks reset it.
    Invoke-Adb @('shell', 'wm', 'size', $ScreenSize)
    $reportedSize = (Invoke-Adb @('shell', 'wm', 'size') -CaptureOutput | Out-String)
    if ($reportedSize -notmatch [regex]::Escape($ScreenSize)) {
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
        if (-not (Confirm-YesByDefault 'Change to World/Castle View. Ready to start?')) {
            Write-Host 'Stopped before clicking.'
            break
        }

        if (-not (Confirm-YesByDefault 'Stamina is greater than 10?')) {
            Write-Host 'Stopped before clicking.'
            break
        }
    }

    if ($firstCycle) {
        $cycleClickIndices = @(0, 1, 2)
    }
    else {
        $cycleClickIndices = @(1, 2)
    }

    foreach ($i in $cycleClickIndices) {
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
    $waitUntil = $finishedAt.AddMilliseconds([int64]($IntervalHours * 3600000))
    $timestamp = $finishedAt.ToString('yyyy-MM-dd HH:mm:ss')

    do {
        $remaining = $waitUntil - (Get-Date)
        if ($remaining.TotalSeconds -lt 0) {
            $remaining = [TimeSpan]::Zero
        }

        $secondsRemaining = [int][Math]::Ceiling($remaining.TotalSeconds)
        $countdown = [TimeSpan]::FromSeconds($secondsRemaining)
        $hours = [int][Math]::Floor($countdown.TotalHours)
        $countdownText = '{0:00}:{1:00}:{2:00}' -f $hours, $countdown.Minutes, $countdown.Seconds
        Write-Host -NoNewline "`r[$timestamp] Waiting $countdownText to restart monsters."

        if ($secondsRemaining -gt 0) {
            Start-Sleep -Seconds 1
        }
    } while ($secondsRemaining -gt 0)

    Write-Host
}
