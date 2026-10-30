# sync-upstream.ps1
# Syncs this fork with upstream (FaFre/WebLibre), rebuilds, and optionally
# publishes a release. Run from the repo root.
#
# Usage:
#   .\scripts\sync-upstream.ps1            # fetch + merge + debug build
#   .\scripts\sync-upstream.ps1 -Release    # also build release APK + update release
#   .\scripts\sync-upstream.ps1 -Tag v0.40.2

param(
    [switch]$Release,
    [string]$Tag = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location $RepoRoot

# 1. Fetch upstream
git fetch upstream --tags
git remote add upstream https://github.com/FaFre/WebLibre.git 2>$null

# 2. Merge upstream/main, keeping our changes on conflict (ours wins for our files)
git merge upstream/main --no-edit
if ($LASTEXITCODE -ne 0) {
    Write-Host "Merge conflicts detected. Resolve them, then re-run." -ForegroundColor Red
    exit 1
}

# 3. Push
git push origin main

# 4. Build
$env:JAVA_HOME = "C:\jdk17"
$env:ANDROID_HOME = "C:\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_NDK_HOME = "C:\Android\Sdk\ndk\29.0.14206865"
$env:FLUTTER_ROOT = "C:\fl\flutter"
$env:GRADLE_USER_HOME = "C:\gradlehome"
$env:PUB_CACHE = "C:\pubcache"
$env:RUSTUP_TOOLCHAIN = "stable-x86_64-pc-windows-gnu"
$env:PATH = "C:\mingw\mingw64\bin;C:\Users\Jamiee!!!\.cargo\bin;C:\tools;C:\fl\flutter\bin\cache\dart-sdk\bin;C:\fl\flutter\bin\mingit\cmd;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:PATH"

Set-Location "$RepoRoot\apps\weblibre"

if ($Release) {
    $ks = "C:\Users\Jamiee!!!\AppData\Local\Temp\opencode\weblibre-release.jks"
    $env:KEY_ALIAS = "weblibre"
    $env:KEY_PASSWORD = "changeit"
    $env:KEY_PATH = $ks
    flutter build apk --release --flavor stable
    $apk = "build\app\outputs\flutter-apk\app-stable-release.apk"
} else {
    flutter build apk --debug --flavor stable
    $apk = "build\app\outputs\flutter-apk\app-stable-debug.apk"
}

if (-not (Test-Path $apk)) { throw "Build did not produce $apk" }

# 5. Release (only with -Release)
if ($Release -and $Tag) {
    $env:GH_TOKEN = (git credential fill 2>$null | Select-String "password=" | ForEach-Object { $_.Line -replace "password=","" })
    gh release create $Tag $apk --repo apauruseya-stack/WebLibre --title "WebLibre $Tag" --notes "Synced with upstream + local patches."
    git tag $Tag
    git push origin $Tag
}

Write-Host "Done. APK: $apk" -ForegroundColor Green