from flask import Flask, render_template, request, jsonify, abort, url_for
from pathlib import Path
import requests
import logging

from counter1911 import run_counter_video_1911

app = Flask(__name__)

BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
VIDEO_FILE = STATIC_DIR / "videos" / "congestion.mp4"

OUTPUT_DIR = BASE_DIR / "outputs"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

MODEL_PATH = BASE_DIR / "yolov8n.pt"

# ================= Firebase config =================
FIREBASE_DB_URL = "https://visiflowapk-a036d-default-rtdb.asia-southeast1.firebasedatabase.app/"
FIREBASE_AUTH = ""  # nếu bạn có secret/ID token thì đặt vào đây

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")


def firebase_url(path: str) -> str:
    """
    path: ví dụ 'roi/points' hoặc 'roi/points_live'
    """
    base = FIREBASE_DB_URL if FIREBASE_DB_URL.endswith("/") else FIREBASE_DB_URL + "/"
    url = base + path + ".json"
    if FIREBASE_AUTH:
        url += f"?auth={FIREBASE_AUTH}"
    return url


# ================= Routes =================
@app.get("/")
def index_1911():
    # truyền đường dẫn video file cho UI (mode=video)
    video_url = url_for("static", filename="videos/congestion.mp4")
    return render_template("index1911.html", video_url=video_url)


@app.get("/current_roi_1911")
def current_roi_1911():
    """
    GET /current_roi_1911?mode=video|live
    video -> roi/points
    live  -> roi/points_live
    """
    mode = request.args.get("mode", "video")
    if mode == "live":
        fb_path = "roi/points_live"
    else:
        fb_path = "roi/points"

    try:
        r = requests.get(firebase_url(fb_path), timeout=5)
        r.raise_for_status()
        pts = r.json() or []
    except Exception as e:
        app.logger.error("Firebase read error: %s", e)
        pts = []

    if not isinstance(pts, list):
        pts = []

    return jsonify(points=pts)


@app.post("/save_roi_1911")
def save_roi_1911():
    """
    Body JSON:
    {
      "points": [ {"x": int, "y": int}, ... 4 điểm ],
      "sourceType": "video" | "live"
    }
    """
    if not request.is_json:
        abort(400, "JSON required")

    body = request.get_json() or {}
    pts = body.get("points", [])
    source_type = (body.get("sourceType") or "video").lower()

    if len(pts) != 4:
        abort(400, "Need exactly 4 points")

    for p in pts:
        p["x"] = int(p["x"])
        p["y"] = int(p["y"])

    # chọn key Firebase
    if source_type == "live":
        fb_key = "roi/points_live"
    else:
        fb_key = "roi/points"

    # ghi Firebase
    try:
        r = requests.put(firebase_url(fb_key), json=pts, timeout=10)
        r.raise_for_status()
    except Exception as e:
        app.logger.error("Firebase write error: %s", e)
        abort(502, f"Firebase write failed: {e}")

    roi_points = [(p["x"], p["y"]) for p in pts]

    # Nếu là VIDEO -> chạy luôn YOLO + đếm và sinh file
    if source_type == "video":
        excel_path = OUTPUT_DIR / "video_counts_1911.xlsx"
        overlay_path = OUTPUT_DIR / "video_overlay_1911.mp4"

        result = run_counter_video_1911(
            video_path=str(VIDEO_FILE),
            model_path=str(MODEL_PATH),
            roi_points=roi_points,
            excel_path=str(excel_path),
            overlay_path=str(overlay_path),
            window_sec=5,
        )

        return jsonify(
            ok=True,
            sourceType=source_type,
            points=pts,
            excel=str(excel_path),
            overlay=str(overlay_path),
            result=result,
        )

    # Nếu là LIVE -> chỉ lưu ROI, phần đếm do live_counter1911.py xử lý
    return jsonify(
        ok=True,
        sourceType=source_type,
        points=pts,
        message="ROI for live saved. Run live_counter1911.py to start counting.",
    )


if __name__ == "__main__":
    # host 0.0.0.0 để máy khác trong LAN xem UI được
    app.run(host="0.0.0.0", port=5000, debug=True)

