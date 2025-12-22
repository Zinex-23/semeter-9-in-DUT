# Hướng dẫn cài đặt Java JDK cho Flutter Android Build

## Bước 1: Download JDK 17 (Recommended cho Flutter)

1. Truy cập: https://adoptium.net/temurin/releases/
2. Chọn:
   - Version: 17 (LTS) 
   - Operating System: Windows
   - Architecture: x64
   - Package Type: JDK
3. Download file .msi và cài đặt

## Bước 2: Set JAVA_HOME Environment Variable

### Cách 1: Qua System Properties
1. Nhấn Windows + R → gõ "sysdm.cpl" → Enter
2. Tab "Advanced" → "Environment Variables"
3. Trong "System Variables" → "New"
4. Variable name: JAVA_HOME
5. Variable value: C:\Program Files\Eclipse Adoptium\jdk-17.0.x.x-hotspot
   (Thay x.x bằng version number thực tế)
6. OK → OK → OK

### Cách 2: Qua PowerShell (Admin)
```powershell
# Set JAVA_HOME (thay path cho đúng)
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot", [System.EnvironmentVariableTarget]::Machine)

# Add to PATH
$currentPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("PATH", "$currentPath;%JAVA_HOME%\bin", [System.EnvironmentVariableTarget]::Machine)
```

## Bước 3: Verify Installation

Mở PowerShell mới và test:
```powershell
java -version
javac -version
echo $env:JAVA_HOME
```

Kết quả mong đợi:
```
openjdk version "17.0.x" 2024-xx-xx
OpenJDK Runtime Environment Temurin-17.0.x+x (build 17.0.x+x)
OpenJDK 64-Bit Server VM Temurin-17.0.x+x (build 17.0.x+x, mixed mode, sharing)
```

## Bước 4: Build Flutter APK

Sau khi cài Java thành công:
```bash
cd "d:\final_year\PBL6\code\pbl6_app"

# Clean build cache
flutter clean
flutter pub get

# Build debug APK (for testing)
flutter build apk --debug

# Build release APK (for distribution)
flutter build apk --release
```

## Troubleshooting

### Lỗi: "JAVA_HOME is set to an invalid directory"
- Kiểm tra path trong JAVA_HOME có tồn tại không
- Restart PowerShell/Command Prompt sau khi set environment variable
- Restart computer nếu cần thiết

### Lỗi: "java: command not found"
- Kiểm tra PATH environment variable có chứa %JAVA_HOME%\bin không
- Thêm C:\Program Files\Eclipse Adoptium\jdk-17.0.x.x-hotspot\bin vào PATH

### Alternative: Android Studio JDK
Nếu đã có Android Studio:
1. Mở Android Studio → File → Project Structure → SDK Location
2. Copy JDK location (thường là: C:\Program Files\Android\Android Studio\jre)
3. Set JAVA_HOME = copied path

## File Locations sau khi build thành công:
- Debug APK: build\app\outputs\flutter-apk\app-debug.apk
- Release APK: build\app\outputs\flutter-apk\app-release.apk

## App Features sau khi build:
✅ Vietnam timezone synchronization
✅ NTP time sync với fallback
✅ Firebase server timestamp
✅ Real-time device state management  
✅ Smart scheduling system
✅ Cross-device time consistency