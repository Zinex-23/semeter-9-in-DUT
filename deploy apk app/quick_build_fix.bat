@echo off
setlocal enabledelayedexpansion

echo ================================================
echo    PBL6 Smart AC - Quick Build Fix
echo ================================================
echo.

echo [INFO] Attempting to fix Java compatibility issue...
echo.

REM Try PowerShell script first
echo [1/3] Trying PowerShell auto-fix...
powershell -ExecutionPolicy Bypass -File "install_java17_and_build.ps1" -Build 2>nul

if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] Build completed successfully!
    goto :end
)

echo [WARN] PowerShell method failed, trying alternative...
echo.

REM Method 2: Try to use existing Android Studio JDK
echo [2/3] Looking for Android Studio JDK...

set "ANDROID_STUDIO_JDK="
for %%p in (
    "C:\Program Files\Android\Android Studio\jbr"
    "C:\Program Files\Android\Android Studio\jre"
) do (
    if exist "%%p\bin\java.exe" (
        echo [FOUND] Android Studio JDK: %%p
        set "ANDROID_STUDIO_JDK=%%p"
        goto :found_studio_jdk
    )
)

echo [INFO] Android Studio JDK not found
goto :manual_install

:found_studio_jdk
echo [INFO] Configuring Flutter to use Android Studio JDK...
flutter config --jdk-dir="%ANDROID_STUDIO_JDK%"

echo [INFO] Building with Android Studio JDK...
set "JAVA_HOME=%ANDROID_STUDIO_JDK%"
set "PATH=%ANDROID_STUDIO_JDK%\bin;%PATH%"

flutter clean
flutter pub get
flutter build apk --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ================================================
    echo    BUILD SUCCESSFUL WITH ANDROID STUDIO JDK!
    echo ================================================
    echo.
    echo APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    
    REM Try AAB build
    echo Building AAB for Play Store...
    flutter build appbundle --release
    
    if !ERRORLEVEL! EQU 0 (
        echo AAB Location: build\app\outputs\bundle\release\app-release.aab
    )
    goto :end
)

:manual_install
echo.
echo [3/3] Manual installation required
echo ================================================
echo    JAVA COMPATIBILITY ISSUE DETECTED
echo ================================================
echo.
echo Your current Java version (Java 25) is not supported by Flutter.
echo Flutter requires Java 11 or Java 17.
echo.
echo QUICK SOLUTIONS:
echo.
echo 1. INSTALL ANDROID STUDIO (Easiest):
echo    - Download: https://developer.android.com/studio
echo    - Android Studio includes compatible JDK
echo    - After install, run this script again
echo.
echo 2. INSTALL JAVA 17 MANUALLY:
echo    - Download: https://adoptium.net/temurin/releases/?version=17
echo    - Install the Windows x64 MSI file
echo    - Restart your terminal and run this script again
echo.
echo 3. RUN AS ADMIN (Auto-install):
echo    - Right-click PowerShell and "Run as Administrator"
echo    - Navigate to this folder
echo    - Run: .\install_java17_and_build.ps1 -Build
echo.
echo After installing compatible Java, your app will build successfully!

:end
echo.
pause