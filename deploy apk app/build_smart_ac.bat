@echo off
setlocal

echo ================================================
echo    PBL6 Smart AC - Build for Google Play Store
echo ================================================
echo.

echo [STEP 1] Checking Java versions...
echo Current Java:
java -version 2>&1 | findstr "version"
echo.

REM Check if Java 17 is available
set "FOUND_JAVA17="

echo [STEP 2] Looking for Java 17...
for %%p in (
    "C:\Program Files\Eclipse Adoptium\jdk-17*"
    "C:\Program Files\Java\jdk-17*"
    "C:\Program Files\OpenJDK\jdk-17*"
    "C:\Program Files (x86)\Eclipse Adoptium\jdk-17*"
) do (
    for /d %%i in (%%p) do (
        if exist "%%i\bin\java.exe" (
            echo [SUCCESS] Found Java 17: %%i
            set "TEMP_JAVA_HOME=%%i"
            set "FOUND_JAVA17=1"
            goto :build_with_java17
        )
    )
)

echo [WARNING] Java 17 not found in standard locations
echo.

REM Try to use Android Studio JDK if available
echo [STEP 3] Looking for Android Studio JDK...
for %%p in (
    "C:\Program Files\Android\Android Studio\jbr"
    "C:\Program Files\Android\Android Studio\jre"
) do (
    if exist "%%p\bin\java.exe" (
        echo [SUCCESS] Found Android Studio JDK: %%p
        set "TEMP_JAVA_HOME=%%p"
        set "FOUND_JAVA17=1"
        goto :build_with_java17
    )
)

echo [ERROR] No compatible Java version found!
echo.
echo Please install Java 17 from:
echo https://adoptium.net/temurin/releases/?version=17
echo.
echo Or install Android Studio which includes compatible JDK.
echo.
pause
exit /b 1

:build_with_java17
echo.
echo [STEP 4] Building with compatible Java...
echo Using: %TEMP_JAVA_HOME%

REM Backup original JAVA_HOME
set "ORIGINAL_JAVA_HOME=%JAVA_HOME%"

REM Set temporary JAVA_HOME
set "JAVA_HOME=%TEMP_JAVA_HOME%"
set "PATH=%JAVA_HOME%\bin;%PATH%"

echo [INFO] Verifying Java version:
java -version

echo.
echo [STEP 5] Cleaning project...
flutter clean

echo.
echo [STEP 6] Getting dependencies...
flutter pub get

echo.
echo [STEP 7] Building release AAB...
flutter build appbundle --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ================================================
    echo          BUILD SUCCESSFUL!
    echo ================================================
    echo.
    echo [SUCCESS] AAB file created at:
    echo build\app\outputs\bundle\release\app-release.aab
    echo.
    echo [INFO] File size:
    for %%A in (build\app\outputs\bundle\release\app-release.aab) do echo %%~zA bytes
    echo.
    echo [NEXT STEPS]:
    echo 1. Upload AAB file to Google Play Console
    echo 2. Add screenshots (see screenshot_guide.md)
    echo 3. Fill in app description
    echo 4. Submit for review
    echo.
) else (
    echo.
    echo [ERROR] Build failed!
    echo Check the error messages above.
    echo.
)

REM Restore original JAVA_HOME
set "JAVA_HOME=%ORIGINAL_JAVA_HOME%"

echo.
echo [STEP 8] Trying to build APK for testing...
set "JAVA_HOME=%TEMP_JAVA_HOME%"
flutter build apk --release

if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] APK file also created at:
    echo build\app\outputs\flutter-apk\app-release.apk
)

REM Final restore
set "JAVA_HOME=%ORIGINAL_JAVA_HOME%"

echo.
pause