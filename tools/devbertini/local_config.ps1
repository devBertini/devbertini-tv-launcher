# Dot-sourced by deploy.ps1, build_release.ps1, install_toolchain.ps1 and pull_banners.ps1:  . "$PSScriptRoot\local_config.ps1"
# Reads tools\devbertini\local.json once (never versioned; local.example.json shows its shape) and answers for what
# is specific to this machine. The Python tools read the same file through local_config.py.
#
#   toolchain_root  the folder of the JDK, Flutter and the Android SDK (default: tools under the user profile)
#   adb             the adb executable; the environment variable ADB wins over it
#                   (default: platform-tools under the toolchain root if it exists, else `adb` on PATH)
#   backups         where deploy.ps1 keeps the launcher's data copies (default: Documents\ltv-launcher-backups)
#   devices         { "<name>": { "serial": "...", "setup": ["<group>", ...] } }
#   weather         { "city": "<name>", "latitude": <deg>, "longitude": <deg> }, the place build_release.ps1 builds
#                   the clock's weather for (lib/devbertini/tv_extras.dart, WeatherPlace); without it, no weather
#   setup           { "<group>": [ { name, why, check, want, fix, on_install } ] }, the checks deploy.ps1 -Setup runs
#                   for a device, in the order of its groups. {pkg} in a check stands for the launcher's package,
#                   {pkg_re} for the same escaped for a regex.
# Windows PowerShell 5.1: no ??, no ?., no -AsHashtable.

$script:LocalConfigFile = Join-Path $PSScriptRoot 'local.json'
$script:LocalConfig = $null
if (Test-Path -LiteralPath $script:LocalConfigFile) {
    try {
        $script:LocalConfig = Get-Content -LiteralPath $script:LocalConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "$($script:LocalConfigFile) is not valid JSON: $($_.Exception.Message)"
    }
}

# One property of an object, or $null when the object or the property is missing.
function Get-Prop($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    $p = $obj.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

function Get-ToolchainRoot {
    $v = Get-Prop $script:LocalConfig 'toolchain_root'
    if ($v) { return [string]$v }
    return (Join-Path $env:USERPROFILE 'tools')
}

function Get-AdbPath {
    if ($env:ADB) { return $env:ADB }
    $v = Get-Prop $script:LocalConfig 'adb'
    if ($v) { return [string]$v }
    $inToolchain = Join-Path (Get-ToolchainRoot) 'android-sdk\platform-tools\adb.exe'
    if (Test-Path -LiteralPath $inToolchain) { return $inToolchain }
    return 'adb'
}

# The weather's place as the app's build settings (WEATHER_CITY, WEATHER_LATITUDE, WEATHER_LONGITUDE), the
# coordinates written with a dot whatever the PC's culture; $null when local.json names no complete place.
function Get-WeatherDefines {
    $w = Get-Prop $script:LocalConfig 'weather'
    $city = [string](Get-Prop $w 'city'); $lat = Get-Prop $w 'latitude'; $lon = Get-Prop $w 'longitude'
    if (-not $city -or $null -eq $lat -or $null -eq $lon) { return $null }
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    return [ordered]@{
        WEATHER_CITY = $city
        WEATHER_LATITUDE = ([double]$lat).ToString($inv)
        WEATHER_LONGITUDE = ([double]$lon).ToString($inv)
    }
}

function Get-BackupsRoot {
    $v = Get-Prop $script:LocalConfig 'backups'
    if ($v) { return [string]$v }
    return (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'ltv-launcher-backups')
}

# The device names of local.json in file order, as objects with Name, Serial and Setup (the group names).
function Get-LocalDevices {
    $list = @()
    $devices = Get-Prop $script:LocalConfig 'devices'
    if ($null -eq $devices) { return $list }
    foreach ($p in $devices.PSObject.Properties) {
        $list += [pscustomobject]@{ Name = $p.Name; Serial = [string](Get-Prop $p.Value 'serial'); Setup = @(@(Get-Prop $p.Value 'setup') | Where-Object { $_ }) }
    }
    return $list
}

# { name = serial } of the named devices.
function Get-DeviceSerials {
    $map = @{}
    foreach ($d in (Get-LocalDevices)) { if ($d.Serial) { $map[$d.Name] = $d.Serial } }
    return $map
}

# The setup checks of one device, in order: the groups listed for it in local.json, or the "common" group for a
# device that is not named there (an ip:port or a serial).
function Get-SetupChecks([string]$device) {
    $groups = @('common')
    foreach ($d in (Get-LocalDevices)) { if ($d.Name -eq $device) { $groups = $d.Setup } }
    $setup = Get-Prop $script:LocalConfig 'setup'
    $checks = @()
    foreach ($g in $groups) {
        foreach ($c in @(Get-Prop $setup ([string]$g))) { if ($null -ne $c) { $checks += $c } }
    }
    return $checks
}
