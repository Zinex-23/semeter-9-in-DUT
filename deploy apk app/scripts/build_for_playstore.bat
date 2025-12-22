@echo off
echo ================================================
echo    Building PBL6 Smart AC for Google Play Store
echo ================================================
echo.

REM Backup current JAVA_HOME
set "ORIGINAL_JAVA_HOME=%JAVA_HOME%"

echo [INFO] Checking current Java version...
java -version 2>&1 | findstr "version" > temp_java_version.txt
for /f "tokens=3 delims= " %%a in (temp_java_version.txt) do (
    set JAVA_VERSION=%%a
    goto :parse_version
)

:parse_version
echo [INFO] Current Java: %JAVA_VERSION%
del temp_java_version.txt 2>nul

REM Try to find compatible Java versions
echo [INFO] Searching for compatible Java versions...

REM Check multiple possible locations for Java 17
set "JAVA_17_FOUND="
for %%p in (
    "C:\Program Files\Eclipse Adoptium\jdk-17*"
    "C:\Program Files\Java\jdk-17*"
    "C:\Program Files\OpenJDK\jdk-17*"
    "C:\Program Files (x86)\Eclipse Adoptium\jdk-17*"
) do (
    for /d %%i in (%%p) do (
        if exist "%%i\bin\java.exe" (
            set "JAVA_HOME=%%i"
            set "JAVA_17_FOUND=1"
            echo [SUCCESS] Found Java 17: %%i
            goto :build
        )
    )
)

REM Check for Java 11 if 17 not found
if not defined JAVA_17_FOUND (
    echo [WARN] Java 17 not found, checking for Java 11...
    for %%p in (
        "C:\Program Files\Eclipse Adoptium\jdk-11*"
        "C:\Program Files\Java\jdk-11*"
        "C:\Program Files\OpenJDK\jdk-11*"
    ) do (
        for /d %%i in (%%p) do (
            if exist "%%i\bin\java.exe" (
                set "JAVA_HOME=%%i"
                echo [SUCCESS] Found Java 11: %%i
                goto :build
            )
        )
    )
)

REM If no compatible Java found, show instructions
echo.
echo [ERROR] Compatible Java version not found!
echo [INFO] Current Java version appears to be: %JAVA_VERSION%
echo [INFO] Flutter requires Java 11 or 17 for building Android apps.
echo.
echo [SOLUTION] Please install Java 17:
echo 1. Download from: https://adoptium.net/temurin/releases/?version=17
echo 2. Install and restart your terminal
echo 3. Run this script again
echo.
echo [ALTERNATIVE] Use Flutter config to set Java path:
echo flutter config --jdk-dir="path\to\your\java"
echo.
pause
exit /b 1

:build
echo.
echo Cleaning project...
call flutter clean

echo.
echo Getting dependencies...
call flutter pub get

echo.
echo Building release APK...
call flutter build apk --release

echo.
echo Building release App Bundle (AAB)...
call flutter build appbundle --release

echo.
echo Build completed!
echo.
echo APK location: build\app\outputs\flutter-apk\app-release.apk
echo AAB location: build\app\outputs\bundle\release\app-release.aab
echo.

REM Restore original JAVA_HOME
set "JAVA_HOME=%ORIGINAL_JAVA_HOME%"

pause