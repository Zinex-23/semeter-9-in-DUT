# Java 17 Auto-Install Script for Flutter Build
param(
    [switch]$SkipDownload,
    [switch]$Build
)

$ErrorActionPreference = "Continue"

Write-Host "============================================" -ForegroundColor Green
Write-Host "  PBL6 Smart AC - Java Fix & Build Script" -ForegroundColor Green  
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# Constants
$java17Url = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.13%2B11/OpenJDK17U-jdk_x64_windows_hotspot_17.0.13_11.msi"
$java17Dir = "C:\Program Files\Eclipse Adoptium\jdk-17.0.13.11-hotspot"
$downloadPath = "$env:TEMP\OpenJDK17.msi"

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Find-JavaVersion {
    param([string]$version)
    
    $searchPaths = @(
        "C:\Program Files\Eclipse Adoptium\jdk-$version*",
        "C:\Program Files\Java\jdk-$version*", 
        "C:\Program Files\OpenJDK\jdk-$version*",
        "C:\Program Files (x86)\Eclipse Adoptium\jdk-$version*"
    )
    
    foreach ($path in $searchPaths) {
        $found = Get-ChildItem $path -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
        if ($found) {
            return $found[0].FullName
        }
    }
    return $null
}

function Test-JavaCompatible {
    try {
        $javaVersion = & java -version 2>&1 | Select-String "version" | ForEach-Object { $_.ToString() }
        if ($javaVersion -match '"(\d+)') {
            $majorVersion = [int]$matches[1]
            return ($majorVersion -eq 11 -or $majorVersion -eq 17)
        }
    } catch {}
    return $false
}

Write-Host "[STEP 1] Checking current Java installation..." -ForegroundColor Yellow

# Check current Java
try {
    $currentJava = & java -version 2>&1
    Write-Host "Current Java:" -ForegroundColor Cyan
    $currentJava | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} catch {
    Write-Host "No Java found in PATH" -ForegroundColor Red
}

Write-Host ""
Write-Host "[STEP 2] Searching for Java 17..." -ForegroundColor Yellow

# Look for Java 17
$java17Path = Find-JavaVersion "17"
if ($java17Path) {
    Write-Host "Found Java 17: $java17Path" -ForegroundColor Green
    $env:JAVA_HOME = $java17Path
    $env:PATH = "$java17Path\bin;$env:PATH"
    
    Write-Host "Testing Java 17..." -ForegroundColor Cyan
    & "$java17Path\bin\java" -version
    
    if ($Build) {
        goto BuildApp
    } else {
        Write-Host ""
        Write-Host "Java 17 is ready! Run with -Build parameter to build the app." -ForegroundColor Green
        exit 0
    }
}

Write-Host "Java 17 not found. Need to install..." -ForegroundColor Yellow

if (!$SkipDownload) {
    Write-Host ""
    Write-Host "[STEP 3] Installing Java 17..." -ForegroundColor Yellow
    
    if (!(Test-AdminRights)) {
        Write-Host ""
        Write-Host "Admin rights required for installation." -ForegroundColor Red
        Write-Host "Right-click PowerShell and 'Run as Administrator', then run:" -ForegroundColor Yellow
        Write-Host "  .\install_java17.ps1" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Or download manually from:" -ForegroundColor Yellow
        Write-Host "  https://adoptium.net/temurin/releases/?version=17" -ForegroundColor Cyan
        exit 1
    }
    
    try {
        Write-Host "Downloading Java 17..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $java17Url -OutFile $downloadPath -UseBasicParsing
        
        Write-Host "Installing Java 17..." -ForegroundColor Cyan
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $downloadPath, "/quiet", "/norestart" -Wait
        
        Write-Host "Cleaning up..." -ForegroundColor Cyan
        Remove-Item $downloadPath -ErrorAction SilentlyContinue
        
        # Check if installation succeeded
        Start-Sleep -Seconds 3
        $java17Path = Find-JavaVersion "17"
        
        if ($java17Path) {
            Write-Host "Java 17 installed successfully!" -ForegroundColor Green
            $env:JAVA_HOME = $java17Path
            $env:PATH = "$java17Path\bin;$env:PATH"
        } else {
            throw "Installation verification failed"
        }
        
    } catch {
        Write-Host "Failed to install Java 17: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install manually:" -ForegroundColor Yellow
        Write-Host "1. Download from: https://adoptium.net/temurin/releases/?version=17" -ForegroundColor Cyan
        Write-Host "2. Install the MSI file" -ForegroundColor Cyan  
        Write-Host "3. Run this script again with -Build" -ForegroundColor Cyan
        exit 1
    }
}

:BuildApp
Write-Host ""
Write-Host "[STEP 4] Building Flutter app..." -ForegroundColor Yellow

# Set Flutter to use our Java
& flutter config --jdk-dir="$java17Path"

Write-Host "Verifying Flutter Java config..." -ForegroundColor Cyan
& flutter doctor -v | Select-String "Java"

Write-Host ""
Write-Host "Building release APK..." -ForegroundColor Cyan
& flutter clean
& flutter pub get  
& flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=================================" -ForegroundColor Green
    Write-Host "   BUILD SUCCESSFUL! 🎉" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "APK Location:" -ForegroundColor Yellow
    Write-Host "  build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
    
    # Try to build AAB as well
    Write-Host ""
    Write-Host "Building release AAB for Google Play..." -ForegroundColor Cyan
    & flutter build appbundle --release
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "AAB Location:" -ForegroundColor Yellow  
        Write-Host "  build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Cyan
        
        # Show file sizes
        $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
        $aabPath = "build\app\outputs\bundle\release\app-release.aab"
        
        if (Test-Path $apkPath) {
            $apkSize = [math]::Round((Get-Item $apkPath).Length / 1MB, 2)
            Write-Host "APK Size: $apkSize MB" -ForegroundColor Gray
        }
        
        if (Test-Path $aabPath) {
            $aabSize = [math]::Round((Get-Item $aabPath).Length / 1MB, 2)
            Write-Host "AAB Size: $aabSize MB" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "Ready for Google Play Store upload! 🚀" -ForegroundColor Green
    }
    
} else {
    Write-Host ""
    Write-Host "Build failed! ❌" -ForegroundColor Red
    Write-Host "Check error messages above." -ForegroundColor Yellow
}

Write-Host ""