import math
import random
import time
from datetime import datetime, timedelta, timezone
import pytz
import firebase_admin
from firebase_admin import credentials, firestore

# ====== CẤU HÌNH ======
PROJECT_TIMEZONE = pytz.timezone("Asia/Ho_Chi_Minh")  # +07:00
COLLECTION_NAME = "readings"                          # tên collection
STEP_MINUTES = 30                                     # cách 30 phút 1 điểm
MONTHS_BACK = 3                                       # bơm 3 tháng gần nhất
BATCH_SIZE = 500                                      # Firestore giới hạn ~500 write/lần commit
SEED = 42                                             # để tái lập; đổi nếu muốn ngẫu nhiên khác
# ======================

random.seed(SEED)

cred = credentials.Certificate("serviceAccount2.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

def vietnam_datetime_str(dt_local: datetime) -> str:
    return dt_local.strftime("%Y-%m-%d %H:%M:%S %z")[:-2] + ":" + dt_local.strftime("%z")[-2:]

def synth_values(dt_local: datetime):
    """
    Sinh dữ liệu 'hợp lý':
    - temperature_c: 23–33°C, đỉnh đầu chiều
    - humidity_pct: 45–85%, ngược pha nhiệt độ
    - eCO2_ppm: 400–800 ppm, tăng nhẹ giờ làm việc
    - TVOC_ppb: 80–600 ppb, tăng khi nóng/ẩm & giờ làm việc
    - IAQ: 5–150, xấu hơn khi eCO2/TVOC cao và môi trường khó chịu
    """
    hour = dt_local.hour + dt_local.minute/60

    # Nhiệt độ
    temp = 28 + 5 * math.sin((hour - 15) / 24 * 2 * math.pi) + random.uniform(-0.6, 0.6)
    temp = round(max(18, min(38, temp)), 2)

    # Độ ẩm
    humidity = 65 - 10 * math.sin((hour - 15) / 24 * 2 * math.pi) + random.uniform(-4, 4)
    humidity = round(max(30, min(95, humidity)), 1)

    # eCO2
    work_factor = 1.0 + (0.25 if 8 <= hour <= 18 else -0.05)
    eCO2 = 450 * work_factor + random.uniform(-40, 180)
    eCO2 = int(max(380, min(1200, eCO2)))

    # TVOC (ppb): nền ~150, cao hơn giờ làm & khi nóng/ẩm
    base_tvoc = 150 * work_factor
    heat_humid_boost = max(0, temp - 30) * 8 + max(0, humidity - 70) * 4
    tvoc = base_tvoc + heat_humid_boost + random.uniform(-40, 120)
    tvoc = int(max(80, min(600, tvoc)))

    # IAQ tổng hợp
    iaq_base = 5 + (eCO2 - 400) / 8.0 + (tvoc - 100) / 6.0
    discomfort = max(0, temp - 30) * 2 + max(0, 60 - humidity) * 0.4 + max(0, humidity - 80) * 0.6
    iaq = int(max(1, min(150, iaq_base + discomfort + random.uniform(-8, 8))))

    return iaq, eCO2, humidity, temp, tvoc

def push_data_to_firestore(current):
    """
    Hàm này để bắn dữ liệu vào Firestore
    """
    iaq, eCO2, humidity, temp, tvoc = synth_values(current)
    ts_seconds = int(current.astimezone(timezone.utc).timestamp())
    doc_id = str(ts_seconds)
    doc_ref = db.collection(COLLECTION_NAME).document(doc_id)

    data = {
        "IAQ": iaq,
        "datetime": vietnam_datetime_str(current),  # ví dụ "2025-09-23 00:45:24 +07:00"
        "eCO2_ppm": eCO2,
        "humidity_pct": humidity,
        "temperature_c": temp,
        "TVOC_ppb": tvoc,   # <— field TVOC
        "ts": ts_seconds,
    }

    doc_ref.set(data)

def backfill_data():
    """
    Bắn dữ liệu quá khứ vào Firestore từ start_local đến end_local
    """
    now_utc = datetime.now(timezone.utc)
    end_local = now_utc.astimezone(PROJECT_TIMEZONE).replace(second=3, microsecond=27)
    minute = 0 if end_local.minute < 30 else 30
    end_local = end_local.replace(minute=minute)

    start_local = (end_local - timedelta(days=31*MONTHS_BACK))
    step = timedelta(minutes=STEP_MINUTES)

    total_points = int((end_local - start_local) / step) + 1
    print(f"Will backfill ~{total_points} documents into '{COLLECTION_NAME}' (every {STEP_MINUTES}m)")

    batch = db.batch()
    written = 0
    batch_count = 0

    current = start_local
    while current <= end_local:
        iaq, eCO2, humidity, temp, tvoc = synth_values(current)
        ts_seconds = int(current.astimezone(timezone.utc).timestamp())
        doc_id = str(ts_seconds)
        doc_ref = db.collection(COLLECTION_NAME).document(doc_id)

        data = {
            "IAQ": iaq,
            "datetime": vietnam_datetime_str(current),  # ví dụ "2025-09-23 00:45:24 +07:00"
            "eCO2_ppm": eCO2,
            "humidity_pct": humidity,
            "temperature_c": temp,
            "TVOC_ppb": tvoc,   # <— field TVOC
            "ts": ts_seconds,
        }

        batch.set(doc_ref, data)
        batch_count += 1
        written += 1

        if batch_count >= BATCH_SIZE:
            batch.commit()
            print(f"Committed {written} / {total_points}")
            batch = db.batch()
            batch_count = 0

        current += step

    if batch_count > 0:
        batch.commit()
        print(f"Committed {written} / {total_points}")

    print("Backfill complete.")

def schedule_data_push():
    """
    Hàm này sẽ chạy theo chu kỳ mỗi 30 phút và bắn dữ liệu vào các mốc giờ xx:00 và xx:30
    """
    while True:
        now_utc = datetime.now(timezone.utc)
        end_local = now_utc.astimezone(PROJECT_TIMEZONE).replace(second=0, microsecond=27)

        # Tính mốc giờ xx:00 hoặc xx:30 gần nhất
        if end_local.minute < 30:
            next_push = end_local.replace(minute=0, second=3, microsecond=27)
        else:
            next_push = end_local.replace(minute=30, second=3, microsecond=27)

        # Tính thời gian chờ (đảm bảo không có giá trị âm)
        wait_time = (next_push - now_utc).total_seconds()

        # Nếu thời gian chờ là âm, có nghĩa là mốc giờ đã qua, ta sẽ chờ đến mốc giờ tiếp theo
        if wait_time < 0:
            next_push = next_push + timedelta(minutes=30)  # Chuyển sang mốc giờ tiếp theo
            wait_time = (next_push - now_utc).total_seconds()

        print(f"Waiting for {wait_time} seconds to push data at {next_push.astimezone(PROJECT_TIMEZONE)}")
        time.sleep(wait_time)  # Đợi đến mốc giờ

        # Bắn dữ liệu vào Firestore
        push_data_to_firestore(next_push)

def main():
    print("Starting backfill and data push cycle...")

    # Bắn dữ liệu quá khứ trước
    backfill_data()

    # Sau khi bắn dữ liệu quá khứ, bắt đầu chu kỳ bắn dữ liệu định kỳ
    schedule_data_push()

if __name__ == "__main__":
    main()
