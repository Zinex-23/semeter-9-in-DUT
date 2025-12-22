# Hướng dẫn chụp Screenshot cho Google Play Store

## 📱 **Yêu cầu kích thước:**

### **Điện thoại (Phone)**
- **Tỷ lệ:** 16:9 
- **Kích thước:** 1920x1080px hoặc 2400x1350px
- **Định dạng:** PNG hoặc JPG
- **Số lượng:** Tối thiểu 2 ảnh, tối đa 8 ảnh

### **Máy tính bảng (Tablet)**
- **Tỷ lệ:** 16:10
- **Kích thước:** 2560x1600px 
- **Định dạng:** PNG hoặc JPG
- **Số lượng:** Tối thiểu 1 ảnh (nếu hỗ trợ tablet)

## 🎯 **Các màn hình nên chụp:**

### **Screenshot 1: Màn hình đăng nhập**
- Hiển thị giao diện đăng nhập/đăng ký
- Thể hiện thiết kế UI sạch sẽ

### **Screenshot 2: Dashboard/Trang chủ** 
- Hiển thị tổng quan thiết bị
- Thống kê nhiệt độ, độ ẩm
- Trạng thái điều hòa

### **Screenshot 3: Điều khiển điều hòa**
- Giao diện điều khiển chính
- Nút bật/tắt, chỉnh nhiệt độ
- Các chế độ hoạt động

### **Screenshot 4: Biểu đồ thống kê**
- Charts hiển thị dữ liệu
- Báo cáo tiêu thụ năng lượng
- Lịch sử hoạt động

### **Screenshot 5: Lập lịch**
- Tính năng scheduling
- Tự động hóa theo thời gian
- AI recommendations

## 🛠️ **Cách chụp:**

### **Trên Android Studio Emulator:**
1. Khởi động emulator với resolution phù hợp
2. Mở app và navigate đến màn hình cần chụp
3. Sử dụng nút camera trên emulator
4. Hoặc dùng phím tắt: Ctrl+S (Windows) / Cmd+S (Mac)

### **Trên thiết bị thật:**
1. Kết nối thiết bị qua USB
2. Bật USB Debugging
3. Sử dụng `adb shell screencap` hoặc các app chụp màn hình

### **Tools hỗ trợ:**
- **Device Art Generator**: Thêm frame thiết bị
- **Figma/Canva**: Chỉnh sửa và thêm text mô tả
- **Android Studio**: Chụp trực tiếp từ emulator

## 📝 **Lưu ý:**
- ✅ Không hiện thông tin cá nhân thật
- ✅ Sử dụng dữ liệu demo/mock
- ✅ UI phải hoàn thiện, không có lỗi hiển thị
- ✅ Ánh sáng đều, không bị mờ
- ❌ Không chụp màn hình lỗi hoặc loading
- ❌ Không có watermark hoặc logo bên thứ 3

## 📂 **Lưu file:**
Lưu tất cả screenshot vào thư mục:
`play_store_assets/screenshots/`

Đặt tên file theo format:
- `phone_01_login.png`
- `phone_02_dashboard.png`
- `phone_03_control.png`
- etc...