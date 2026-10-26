# Builds LTvLauncher DevBertini and puts it on a device in one command: connect (pairing after a reboot),
# install, optionally reapply the device's setup checks (local.json), open the home,
# then disconnect and stop adb.
#
#   deploy.ps1 -Device <name>          build, install on that device, open, disconnect (docs/devbertini/DEVELOPMENT.md)
#   deploy.ps1 -Device <name> -SkipBuild  install the last build
#   deploy.ps1 -ApkPath <file.apk>     install that APK instead of building (a kept copy)
#   deploy.ps1 -Pair <tv-ip>:<port> -Code <6 digits>   after a reboot (Settings, System, Developer options,
#                                      Wireless debugging, Pair device with pairing code)
#   deploy.ps1 -Setup                  also reapply the setup table, changing only what differs
#   deploy.ps1 -KeepConnection         leave adb connected for more work
#   deploy.ps1 -BackupOnly             only copy the launcher's data to the PC
#   deploy.ps1 -Restore <folder>       install, then put a copy back (a folder under ltv-launcher-backups)
#   deploy.ps1 -Restore <folder> -RestoreOnly   put a copy back without installing
#   deploy.ps1 -Art                    also put the HD card art of build\devbertini-art (hd_art.py) and the brand
#                                      logos of build\devbertini-logos (logo_art.py) on the device
#   deploy.ps1 -ShowConfig             print what tools\devbertini\local.json resolves to (adb, devices, backups,
#                                      the number of setup checks) and exit, without connecting
#
# What is specific to this machine (the toolchain and adb paths, the devices' serials, the backups folder and the
# device setup table) is read from tools\devbertini\local.json by local_config.ps1; local.example.json shows its
# shape.
#
# Before every install the launcher's data (every profile, the settings) is copied to
# <the backups folder of local.json>\<device>\<time>, and the install does not run when
# that copy fails: an install can never cost the TV its setup. -NoBackupOnce is only for the one install
# that brings the backup to a launcher built before it.
param(
    [string]$Device = "tcl",
    [switch]$SkipBuild,
    [string]$Pair,
    [string]$Code,
    [switch]$Setup,
    [switch]$KeepConnection,
    [switch]$BackupOnly,
    [string]$Restore,
    [switch]$NoBackupOnce,
    [switch]$RestoreOnly,
    [string]$ApkPath,
    [switch]$Art,
    [switch]$ShowConfig
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\local_config.ps1"
$adb = Get-AdbPath
$proj = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$apk = "$proj\build\app\outputs\flutter-apk\app-release.apk"
if ($ApkPath) { $apk = (Resolve-Path $ApkPath).Path; $SkipBuild = $true }
$pkg = "com.leanbitlab.ltvL"
# Device serials as adb's network discovery names them (adb-<serial>-<suffix>), from local.json.
$known = Get-DeviceSerials
$backups = Get-BackupsRoot
$remote = "/sdcard/Android/data/$pkg/files"
if ($ShowConfig) {
    $found = "not found, defaults apply"; if (Test-Path -LiteralPath $script:LocalConfigFile) { $found = "found" }
    Write-Host "local.json: $script:LocalConfigFile ($found)"
    Write-Host "toolchain: $(Get-ToolchainRoot)"
    Write-Host "adb: $adb"
    Write-Host "backups: $backups"
    $named = @(Get-LocalDevices)
    if ($named.Count -eq 0) { Write-Host "devices: none (give -Device <ip:port> or a serial)" }
    foreach ($d in $named) {
        $tail = $d.Serial; if ($tail.Length -gt 4) { $tail = $tail.Substring($tail.Length - 4) }
        Write-Host "device $($d.Name): serial ...$tail, $(@(Get-SetupChecks $d.Name).Count) setup checks"
    }
    exit 0
}
function Log($m) { Write-Host "$(Get-Date -Format HH:mm:ss) $m" }

function Adb([string[]]$a) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $out = & $adb @a 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $old }
    return (($out | Where-Object { $_ -ne $null }) -join "`n").Trim()
}
function Sh([string]$cmd) { return Adb @('-s', $script:serial, 'shell', $cmd) }

function Resolve-Address([string]$name) {
    if ($name -match '^\d+\.\d+\.\d+\.\d+:\d+$') { return $name }
    $id = $known[$name]
    if (-not $id -and $name -match '^(?=.*\d)[A-Za-z0-9]{8,}$') { $id = $name }
    if (-not $id) {
        $names = (@(Get-LocalDevices) | ForEach-Object { $_.Name }) -join ', '
        if ($names) { throw "unknown device '$name' ($names, a serial or ip:port)" }
        throw "unknown device '$name' (give ip:port or a serial; names come from tools\devbertini\local.json)"
    }
    for ($i = 0; $i -lt 10; $i++) {
        $line = (Adb @('mdns', 'services')) -split "`n" |
            Where-Object { $_ -match "^adb-$id" -and $_ -match '_adb-tls-connect\._tcp' } | Select-Object -First 1
        if ($line -match '(\d+\.\d+\.\d+\.\d+:\d+)') { return $Matches[1] }
        Start-Sleep -Seconds 1
    }
    throw "the $name is not announcing wireless debugging (is it on, and is wireless debugging enabled?)"
}

# One setup item: a check that prints the current state, the state it should have, and the command that sets it.
function Ensure([string]$what, [string]$check, [string]$want, [string]$fix) {
    $now = Sh $check
    if ($now -match $want) { Log "setup ok: $what"; return }
    Sh $fix | Out-Null
    $after = Sh $check
    if ($after -match $want) { Log "setup FIXED: $what" } else { Log "setup STILL WRONG: $what ($after)" }
}

# Expands {pkg} (the launcher's package) and {pkg_re} (the same escaped for a regex) in a check of local.json.
function Expand-Check([string]$text) { return $text.Replace('{pkg}', $pkg).Replace('{pkg_re}', [regex]::Escape($pkg)) }

function Invoke-Checks($checks) {
    foreach ($c in $checks) { Ensure $c.name (Expand-Check $c.check) (Expand-Check $c.want) (Expand-Check $c.fix) }
}

# The device's setup table, from local.json (setup, in the groups listed for the device; a device that is not named
# there gets the "common" group).
function Invoke-Setup([string]$device) {
    $checks = @(Get-SetupChecks $device)
    if ($checks.Count -eq 0) { Log "setup: no checks for '$device' in local.json (see local.example.json)"; return }
    Invoke-Checks $checks
}

# Copies the launcher's data to the PC; returns the folder, or $null when the launcher is not installed.
function Backup-Device([string]$name) {
    if ((Sh "pm list packages $pkg") -notmatch "package:$([regex]::Escape($pkg))(\s|$)") { Log "backup: launcher not installed, nothing to copy"; return $null }
    $answer = Sh "am broadcast -n $pkg/.SnapshotReceiver"
    if ($answer -notmatch 'result=(-?\d+)' -or [int]$Matches[1] -lt 1) {
        throw "backup failed on the device ($answer); nothing was installed (a launcher older than the backup needs one -NoBackupOnce install)"
    }
    $files = [int]$Matches[1]
    $folder = Join-Path $backups "$name\$(Get-Date -Format yyyyMMdd-HHmmss)"
    New-Item -ItemType Directory -Force $folder | Out-Null
    $pulled = Adb @('-s', $script:serial, 'pull', "$remote/snapshot/.", $folder)
    $count = (Get-ChildItem $folder -Recurse -File | Measure-Object).Count
    if ($count -lt $files) { throw "backup copied $count of $files files ($pulled); nothing was installed" }
    Log "backup: $files files in $folder"
    # The newest ten copies per device are kept.
    Get-ChildItem (Join-Path $backups $name) -Directory | Sort-Object Name -Descending | Select-Object -Skip 10 |
        ForEach-Object { Remove-Item -Recurse -Force $_.FullName -Confirm:$false }
    return $folder
}

# Pushes a copy back as one zip (adb's shell may create files in the launcher's folder, not folders); the
# launcher swaps its data for it the next time it starts, before anything reads it, and logs the count.
function Restore-Device([string]$folder) {
    if (-not (Test-Path (Join-Path $folder 'snapshot.txt'))) { throw "$folder is not a launcher backup (no snapshot.txt)" }
    $zip = Join-Path $env:TEMP "ltv-restore.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -Path (Join-Path $folder '*') -DestinationPath $zip
    try {
        Log "restore: $(Adb @('-s', $script:serial, 'push', $zip, "$remote/restore.zip"))"
    } finally {
        Remove-Item $zip -Force
    }
    Adb @('-s', $script:serial, 'logcat', '-c') | Out-Null
    Sh "am force-stop $pkg" | Out-Null
    Sh "am start -n $pkg/.MainActivity" | Out-Null
    Start-Sleep -Seconds 5
    $said = Adb @('-s', $script:serial, 'logcat', '-d', '-s', 'DevBertiniSnapshot')
    if ($said -notmatch 'snapshot restored: (\d+) files' -or [int]$Matches[1] -lt 1) { throw "the launcher did not restore the copy ($said)" }
    Log "restore: $($Matches[1]) files back from $folder"
}

# Puts each build\devbertini-art\<package>.png in the launcher's external files as hd_<package>.png, where it
# looks for HD card art before the app's own banner (lib/devbertini/art_cache.dart, HdArt), and each
# build\devbertini-logos\logo_*.png (tools/devbertini/logo_art.py) there under its own name, where the home reads
# its brand logos (lib/devbertini/vitrine/logos.dart). No logos is a warning: the home falls back without them.
function Push-Art {
    $images = Get-ChildItem "$proj\build\devbertini-art" -Filter *.png | Where-Object { $_.BaseName -match '^[a-z][\w]*(\.[\w]+)+$' }
    if (-not $images) { throw "no HD art in $proj\build\devbertini-art (run tools\devbertini\hd_art.py first)" }
    foreach ($image in $images) {
        $pushed = Adb @('-s', $script:serial, 'push', $image.FullName, "$remote/hd_$($image.Name)")
        if ($pushed -notmatch '1 file pushed') { throw "art push failed for $($image.Name): $pushed" }
    }
    $logos = @()
    if (Test-Path "$proj\build\devbertini-logos") { $logos = @(Get-ChildItem "$proj\build\devbertini-logos" -Filter 'logo_*.png') }
    if ($logos.Count -eq 0) { Log "art: WARNING no logos in $proj\build\devbertini-logos (run tools\devbertini\logo_art.py first); the home draws its fallbacks" }
    foreach ($logo in $logos) {
        $pushed = Adb @('-s', $script:serial, 'push', $logo.FullName, "$remote/$($logo.Name)")
        if ($pushed -notmatch '1 file pushed') { throw "logo push failed for $($logo.Name): $pushed" }
    }
    Log "art: $($images.Count) HD images and $($logos.Count) logos on the device"
}

try {
    if (-not $SkipBuild -and -not $BackupOnly -and -not $RestoreOnly) {
        & "$PSScriptRoot\build_release.ps1"
        if ($LASTEXITCODE -ne 0) { throw "build failed" }
    }
    if (-not $BackupOnly -and -not $RestoreOnly -and -not (Test-Path $apk)) { throw "no APK at $apk" }
    if ($Restore -and -not (Test-Path (Join-Path $Restore 'snapshot.txt'))) { throw "$Restore is not a launcher backup (no snapshot.txt)" }
    Adb @('start-server') | Out-Null
    if ($Pair) {
        if (-not $Code) { throw "-Pair needs -Code (the 6 digits on the screen)" }
        Log "pair: $(Adb @('pair', $Pair, $Code))"
    }
    $script:serial = Resolve-Address $Device
    Log "connect: $(Adb @('connect', $script:serial))"
    if ((Adb @('-s', $script:serial, 'get-state')) -ne 'device') { throw "the $Device at $($script:serial) did not accept the connection (pair it again)" }
    $name = $Device; if ($Device -match ':') { $name = $Device -replace '[:.]', '-' }
    if ($NoBackupOnce) { Log "backup: skipped once by -NoBackupOnce (the installed launcher has no snapshot yet)" } else { Backup-Device $name | Out-Null }
    if ($BackupOnly) { Log "DEPLOY DONE: backup only"; return }
    if ($RestoreOnly) { Restore-Device $Restore; Log "DEPLOY DONE: restore only"; return }
    Log "install $(Split-Path $apk -Leaf) ($([math]::Round((Get-Item $apk).Length / 1MB, 1)) MB)..."
    $result = Adb @('-s', $script:serial, 'install', '-r', $apk)
    if ($result -notmatch 'Success') { throw "install failed: $result" }
    Log "installed: $((Sh "dumpsys package $pkg 2>/dev/null | grep -m1 lastUpdateTime").Trim())"
    if ($Setup) { Invoke-Setup $Device }
    # An update turns the launcher's accessibility service off; the checks of local.json marked on_install (the
    # console watcher) run after every install, not only with -Setup.
    else { Invoke-Checks @(Get-SetupChecks $Device | Where-Object { $_.on_install }) }
    if ($Art) { Push-Art; Sh "am force-stop $pkg" | Out-Null }
    if ($Restore) { Restore-Device $Restore }
    Sh "input keyevent KEYCODE_HOME" | Out-Null
    Start-Sleep -Seconds 4
    $focus = (Sh "dumpsys window 2>/dev/null | grep -m1 mCurrentFocus").Trim()
    if ($focus -match $pkg) { Log "DEPLOY DONE: the home is in front ($focus)" } else { Log "DEPLOY DONE, but the home is not in front: $focus" }
} catch {
    Log "DEPLOY FAILED: $($_.Exception.Message)"; $failed = $true
} finally {
    if (-not $KeepConnection) {
        if ($script:serial) { Adb @('disconnect', $script:serial) | Out-Null }
        Adb @('kill-server') | Out-Null
        Log "adb disconnected and stopped"
    }
}
if ($failed) { exit 1 }
