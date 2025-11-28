from pathlib import Path
import requests
import cv2
import sys

# Import hàm xử lý chính
from counter1911 import run_counter_live_1911

# ================= Cấu hình Firebase =================
# URL này phải khớp với URL trong file 1911.py
FIREBASE_DB_URL = "https://visiflowapk-a036d-default-rtdb.asia-southeast1.firebasedatabase.app/"
FIREBASE_AUTH = ""  # Nếu database có set rules bảo mật thì điền token vào đây

# Đường dẫn thư mục hiện tại
BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "outputs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Đường dẫn model YOLO
MODEL_PATH = BASE_DIR / "yolov8n.pt"

# Camera Index (thường là 0 cho webcam laptop, 1 cho webcam cắm ngoài)
CAM_INDEX = 0


def firebase_url(path: str) -> str:
    """Hàm hỗ trợ tạo URL Firebase"""
    base = FIREBASE_DB_URL if FIREBASE_DB_URL.endswith("/") else FIREBASE_DB_URL + "/"
    url = base + path + ".json"
    if FIREBASE_AUTH:
        url += f"?auth={FIREBASE_AUTH}"
    return url


def load_live_roi_1911():
    """Tải tọa độ ROI từ Firebase (do web 1911.py lưu lên)"""
    print(">>> Đang kết nối Firebase để tải ROI...")
    try:
        r = requests.get(firebase_url("roi/points_live"), timeout=5)
        r.raise_for_status()
        pts = r.json()
        
        if not pts:
            print("!!! CẢNH BÁO: Không tìm thấy dữ liệu ROI trên Firebase.")
            return []
            
        if not isinstance(pts, list) or len(pts) < 3:
            print(f"!!! CẢNH BÁO: Dữ liệu ROI không hợp lệ: {pts}")
            return []

        # Chuyển đổi list of dicts [{'x':.., 'y':..}] thành list of tuples [(x,y),..]
        roi_points = [(int(p["x"]), int(p["y"])) for p in pts]
        print(f">>> Đã tải thành công ROI: {roi_points}")
        return roi_points
        
    except Exception as e:
        print(f"!!! LỖI KẾT NỐI FIREBASE: {e}")
        return []


def main():
    # 1. Tải ROI từ Firebase
    roi_points = load_live_roi_1911()

    # Kiểm tra nếu chưa có ROI
    if not roi_points:
        print("\n" + "="*60)
        print("LỖI: Chưa có vùng ROI (Vùng quan tâm) hợp lệ.")
        print("HƯỚNG DẪN KHẮC PHỤC:")
        print("1. Chạy file server: python 1911.py")
        print("2. Mở trình duyệt, chọn tab 'Webcam Live'")
        print("3. Vẽ 4 điểm bao quanh vùng đường cần giám sát.")
        print("4. Bấm nút 'Save & Process'.")
        print("5. Quay lại đây và chạy lại file này.")
        print("="*60 + "\n")
        return

    # Đường dẫn file excel kết quả
    excel_path = OUTPUT_DIR / "live_counts_1911.xlsx"

    print(f"\n>>> Đang khởi động Camera {CAM_INDEX}...")
    print(">>> Nhấn phím 'q' trên cửa sổ camera để THOÁT.")

    # 2. Gọi hàm xử lý từ counter1911
    try:
        result = run_counter_live_1911(
            cam_index=CAM_INDEX,
            model_path=str(MODEL_PATH),
            roi_points=roi_points,
            excel_path=str(excel_path),
            window_sec=5,      # 5 giây lưu 1 lần
            conf=0.3,          # Độ tin cậy tối thiểu
            iou=0.45,
            show_window=True,  # Hiển thị cửa sổ camera
        )
        print("\n" + "-"*40)
        print("Đã kết thúc phiên Live.")
        print("Kết quả:", result)
        print(f"File Excel được lưu tại: {excel_path}")
        print("-"*40)
        
    except Exception as e:
        print(f"\n!!! LỖI KHI CHẠY CAMERA: {e}")
        print("Hãy kiểm tra lại Camera hoặc Model Path.")

if __name__ == "__main__":
    main()