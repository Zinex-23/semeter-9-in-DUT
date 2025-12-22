# Hướng dẫn Fix Java Issue và Build cho Google Play Store

## 🚨 **Vấn đề hiện tại:**
- Bạn đang dùng Java 25 (`OpenJDK 25`)
- Flutter/Gradle không hỗ trợ Java 25 (chỉ hỗ trợ Java 11-17)
- Lỗi "java.lang.IllegalArgumentException: 25"

## ✅ **Các giải pháp:**

### **Giải pháp 1: Tải Java 17 (Khuyến nghị)**

1. **Tải Java 17:**
   - Truy cập: https://adoptium.net/temurin/releases/?version=17
   - Chọn: `OpenJDK 17 LTS` > `Windows x64` > `JDK` > Download

2. **Cài đặt Java 17:**
   - Chạy file installer
   - Cài vào đường dẫn: `C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot`

3. **Cấu hình Flutter:**
   ```bash
   flutter config --jdk-dir="C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot"
   ```

4. **Build lại:**
   ```bash
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```

### **Giải pháp 2: Sử dụng Android Studio JDK**

1. **Tải Android Studio:**
   - Từ: https://developer.android.com/studio
   - Android Studio có sẵn JDK tương thích

2. **Cấu hình Flutter:**
   ```bash
   flutter config --android-studio-dir="C:\Program Files\Android\Android Studio"
   ```

### **Giải pháp 3: Temporary JAVA_HOME**

Tạo file `build_with_java17.bat`:

```batch
@echo off
echo Setting Java 17 for build...

REM Set temporary JAVA_HOME (update path if needed)
set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.13.11-hotspot
set PATH=%JAVA_HOME%\bin;%PATH%

echo Using Java version:
java -version

echo Building Flutter app...
flutter clean
flutter pub get
flutter build appbundle --release

pause
```

## 🎯 **Sau khi fix Java:**

### **Build commands:**
```bash
# Build AAB cho Play Store (khuyến nghị)
flutter build appbundle --release

# Build APK cho test
flutter build apk --release
```

### **File output:**
- **AAB:** `build/app/outputs/bundle/release/app-release.aab`
- **APK:** `build/app/outputs/flutter-apk/app-release.apk`

## 📱 **Tiếp theo:**

1. ✅ **Upload lên Google Play Console**
2. ✅ **Chuẩn bị screenshots** (xem `screenshot_guide.md`)
3. ✅ **Viết mô tả app** (xem `app_description.md`)
4. ✅ **Tạo Privacy Policy**
5. ✅ **Submit để review**

---

## 🔧 **Troubleshooting:**

**Nếu vẫn lỗi:** Kiểm tra `flutter doctor -v` xem Java path có đúng chưa

**Nếu build thành công:** File AAB sẽ có kích thước khoảng 20-50MB