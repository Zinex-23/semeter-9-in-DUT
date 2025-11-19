from pathlib import Path
import requests

from counter1911 import run_counter_live_1911

# Giống config Firebase trong 1911.py
FIREBASE_DB_URL = "https://visiflowapk-a036d-default-rtdb.asia-southeast1.firebasedatabase.app/"
FIREBASE_AUTH = ""  # nếu có thì thêm

BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "outputs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

MODEL_PATH = BASE_DIR / "yolov8n.pt"
CAM_INDEX = 0  # nếu camera khác index thì chỉnh lại


def firebase_url(path: str) -> str:
    base = FIREBASE_DB_URL if FIREBASE_DB_URL.endswith("/") else FIREBASE_DB_URL + "/"
    url = base + path + ".json"
    if FIREBASE_AUTH:
        url += f"?auth={FIREBASE_AUTH}"
    return url


def load_live_roi_1911():
    r = requests.get(firebase_url("roi/points_live"), timeout=5)
    r.raise_for_status()
    pts = r.json() or []
    if not isinstance(pts, list) or len(pts) < 3:
        raise RuntimeError(f"ROI points_live không hợp lệ: {pts}")
    roi_points = [(int(p["x"]), int(p["y"])) for p in pts]
    return roi_points


def main():
    roi_points = load_live_roi_1911()
    print("ROI points_live:", roi_points)

    excel_path = OUTPUT_DIR / "live_counts_1911.xlsx"

    result = run_counter_live_1911(
        cam_index=CAM_INDEX,
        model_path=str(MODEL_PATH),
        roi_points=roi_points,
        excel_path=str(excel_path),
        window_sec=5,
        conf=0.3,
        iou=0.45,
        show_window=True,
    )

    print("Kết thúc live, kết quả:", result)
    print("File Excel:", excel_path)


if __name__ == "__main__":
    main()
