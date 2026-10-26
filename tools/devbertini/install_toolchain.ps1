# Copyright (C) 2026 Claudio Bertini (devBertini). GPL-3.0-or-later, like the rest of this project.
# Installs the build toolchain into the toolchain root of tools\devbertini\local.json (JDK 21, Flutter 3.47.7, Android SDK with
# platform-tools, android-36 and NDK 28.2.13676358; AGP fetches its own build-tools), each download
# checked against its published hash.
# Run it again only when that folder was removed; the signing key in tools\keys is never made here.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\local_config.ps1"
$root = Get-ToolchainRoot
$dl = "$root\_dl"

function Log($m) { Write-Host "$(Get-Date -Format HH:mm:ss) $m" }

function Get-Verified($url, $name, $file, $algo, $hash) {
    $dir = Join-Path $dl $name
    New-Item -ItemType Directory -Force $dir | Out-Null
    $out = Join-Path $dir $file
    if (-not (Test-Path $out)) {
        Log "downloading $file"
        curl.exe -fsSL -o $out $url
        if ($LASTEXITCODE -ne 0) { throw "download failed: $url" }
    }
    $h = (Get-FileHash -Algorithm $algo $out).Hash.ToLower()
    if ($h -ne $hash.ToLower()) { throw "checksum mismatch for ${file}: $h" }
    Log "verified $file ($algo)"
    return $out
}

try {
    New-Item -ItemType Directory -Force $root | Out-Null

    $jdkZip = Get-Verified "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_windows_hotspot_21.0.12.1_1.zip" "jdk" "jdk21.zip" "SHA256" "f9d6e191ab098c0d416e7d588a24420a8621cd2f4720dab2459b8b7b2d2d8b4e"
    if (-not (Test-Path "$root\jdk-21")) {
        tar -xf $jdkZip -C $root
        $extracted = Get-ChildItem $root -Directory | Where-Object { $_.Name -like 'jdk-21*' -and $_.Name -ne 'jdk-21' } | Select-Object -First 1
        Rename-Item $extracted.FullName "jdk-21"
    }
    $env:JAVA_HOME = "$root\jdk-21"
    Log "jdk ready: $((cmd /c "`"$root\jdk-21\bin\java.exe`" -version 2>&1") | Select-Object -First 1)"

    $flZip = Get-Verified "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.7-stable.zip" "flutter" "flutter.zip" "SHA256" "c2c875da25a1a1448d18ee4e8f398b2f6fce888b4775d8f9130538e16d826cb4"
    if (-not (Test-Path "$root\flutter\bin\flutter.bat")) {
        Log "extracting flutter"
        tar -xf $flZip -C $root
        if ($LASTEXITCODE -ne 0) { throw "flutter extract failed" }
    }
    Log "flutter extracted"

    $ctZip = Get-Verified "https://dl.google.com/android/repository/commandlinetools-win-16111833_latest.zip" "cmdline-tools" "cmdline-tools.zip" "SHA1" "57d04f2d75eb8e8fffc5000a987e5de4b5a63e9d"
    $sdk = "$root\android-sdk"
    if (-not (Test-Path "$sdk\cmdline-tools\latest\bin\sdkmanager.bat")) {
        New-Item -ItemType Directory -Force "$sdk\cmdline-tools" | Out-Null
        tar -xf $ctZip -C "$sdk\cmdline-tools"
        Rename-Item "$sdk\cmdline-tools\cmdline-tools" "latest"
    }

    $env:ANDROID_HOME = $sdk
    $env:Path = "$root\jdk-21\bin;$root\flutter\bin;$sdk\platform-tools;$env:Path"

    Log "accepting SDK licenses"
    $yes = ("y`n" * 20)
    $yes | cmd /c "`"$sdk\cmdline-tools\latest\bin\sdkmanager.bat`" --sdk_root=`"$sdk`" --licenses" | Out-Null
    Log "installing platform-tools, android-36, NDK 28.2.13676358"
    cmd /c "`"$sdk\cmdline-tools\latest\bin\sdkmanager.bat`" --sdk_root=`"$sdk`" platform-tools platforms/android-36 ndk/28.2.13676358 2>&1" | Select-String -Pattern "rror|Warning" | ForEach-Object { Log "sdkmanager: $($_.Line.Trim())" }
    if (-not (Test-Path "$sdk\platforms\android-36")) { throw "android-36 platform missing after sdkmanager" }

    Log "configuring flutter (analytics off)"
    cmd /c "flutter config --no-analytics --android-sdk `"$sdk`" 2>&1" | Out-Null
    cmd /c "flutter --disable-analytics 2>&1" | Out-Null
    cmd /c "dart --disable-analytics 2>&1" | Out-Null
    Log "flutter doctor"
    cmd /c "flutter doctor -v 2>&1" | Select-String -Pattern "^\[|Flutter version|Java version|Android SDK at|Platform android|Build-tools|X " | ForEach-Object { Log "doctor: $($_.Line.Trim())" }
    Remove-Item -LiteralPath $dl -Recurse -Force
    Log "TOOLCHAIN DONE"
}
catch {
    Log "TOOLCHAIN FAILED: $($_.Exception.Message)"
    exit 1
}

