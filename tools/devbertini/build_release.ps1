# Builds the signed release APK of LTvLauncher DevBertini (armeabi-v7a, the TCL C7K's ABI).
# Toolchain and signing key live outside the repository, in the toolchain root of tools\devbertini\local.json
# (keys\ is never versioned: an update must be signed with the same key to install over the old version).
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\local_config.ps1"
$root = Get-ToolchainRoot
$proj = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$keys = "$root\keys"
function Log($m) { Write-Host "$(Get-Date -Format HH:mm:ss) $m" }
$env:JAVA_HOME = "$root\jdk-21"
$env:ANDROID_HOME = "$root\android-sdk"
# LTV_FLUTTER points at another Flutter SDK folder while a toolchain upgrade is tried on its branch.
$flutter = "$root\flutter"
if ($env:LTV_FLUTTER) { $flutter = $env:LTV_FLUTTER }
$env:Path = "$root\jdk-21\bin;$flutter\bin;$root\android-sdk\platform-tools;$env:Path"
try {
    $pw = Get-Content "$keys\ltv-release.pass" -Raw
    $env:KEYSTORE_FILE = "$keys\ltv-release.jks"; $env:KEYSTORE_PASSWORD = $pw; $env:KEY_ALIAS = "ltv"; $env:KEY_PASSWORD = $pw
    $env:UNIVERSAL_ONLY = "true"
    Set-Location $proj
    cmd /c "flutter pub get 2>&1" | Select-String -Pattern "rror|Got dependencies" | ForEach-Object { Log "pub: $($_.Line.Trim())" }
    cmd /c "dart run build_runner build --delete-conflicting-outputs 2>&1" | Select-String -Pattern "rror|Succeeded|Failed|SEVERE" | ForEach-Object { Log "build_runner: $($_.Line.Trim())" }
    # The weather's place goes in through a file of build settings: a city's accents survive it, a cmd line may not.
    $defines = ""
    $weather = Get-WeatherDefines
    if ($weather) {
        $file = "$proj\build\weather-defines.json"
        New-Item -ItemType Directory -Force "$proj\build" | Out-Null
        [System.IO.File]::WriteAllText($file, ($weather | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
        $defines = " --dart-define-from-file=`"$file`""
        Log "weather: $($weather.WEATHER_CITY)"
    } else {
        Log "weather: no place in local.json, the build has no weather"
    }
    cmd /c "flutter build apk --release --target-platform=android-arm$defines 2>&1" | Select-String -Pattern "rror|FAILURE|Built |What went wrong" | ForEach-Object { Log "build: $($_.Line.Trim())" }
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }
    Log "BUILD DONE: $proj\build\app\outputs\flutter-apk\app-release.apk"
} catch {
    Log "BUILD FAILED: $($_.Exception.Message)"; exit 1
}