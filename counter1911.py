import torch

# ====== FIX CHO PYTORCH 2.6: ép torch.load dùng weights_only=False ======
_orig_torch_load = torch.load
def _torch_load_legacy(*args, **kwargs):
    kwargs.setdefault("weights_only", False)
    return _orig_torch_load(*args, **kwargs)
torch.load = _torch_load_legacy
# =======================================================================

from ultralytics import YOLO
import cv2
import numpy as np
import pandas as pd
from collections import defaultdict
from pathlib import Path
from datetime import datetime, timedelta

# 4 loại chính xuất ra Excel
TARGET_LABELS = ("bike", "car", "bus", "truck")

# Map tên class của model -> nhãn chuẩn (canonical)
CLASS_CANONICAL_MAP = {
    "bicycle": "bike",
    "bike": "bike",
    "motorbike": "bike",
    "motorcycle": "bike",
    "car": "car",
    "bus": "bus",
    "truck": "truck",
}


def _is_inside_roi(roi_np: np.ndarray, x1, y1, x2, y2) -> bool:
    """Kiểm tra tâm bbox có nằm trong đa giác ROI hay không."""
    cx = (x1 + x2) / 2.0
    cy = (y1 + y2) / 2.0
    inside = cv2.pointPolygonTest(roi_np, (cx, cy), False)
    return inside >= 0


def _draw_roi_transparent(frame, roi_np, alpha: float = 0.3):
    """Vẽ ROI bán trong suốt, kèm viền màu xanh."""
    overlay = frame.copy()
    cv2.fillPoly(overlay, [roi_np], color=(0, 0, 255))  # đỏ
    frame = cv2.addWeighted(overlay, alpha, frame, 1 - alpha, 0)
    cv2.polylines(frame, [roi_np], isClosed=True, color=(0, 255, 0), thickness=2)
    return frame


# ----------------------------------------------------------------------
# VIDEO MODE – ID-BASED COUNTING + CROP ROI
# ----------------------------------------------------------------------
def run_counter_video_1911(
    video_path: str,
    model_path: str,
    roi_points,
    excel_path: str,
    overlay_path: str,
    window_sec: int = 5,
    conf: float = 0.3,
    iou: float = 0.45,
):
    """
    Đếm THEO ID cho VIDEO:
    - YOLO chỉ xử lý vùng bounding box của ROI (crop) để tăng tốc.
    - Mỗi xe đi qua ROI chỉ được cộng 1 lần, tại thời điểm nó rời ROI (ID biến mất).
    - Mỗi window_sec (mặc định 5s) ghi 1 dòng Excel.
    """
    video_path = str(video_path)
    excel_path = str(excel_path)
    overlay_path = str(overlay_path)

    roi_np = np.array(roi_points, dtype=np.int32)
    xs = roi_np[:, 0]
    ys = roi_np[:, 1]
    x_min_roi, x_max_roi = int(xs.min()), int(xs.max())
    y_min_roi, y_max_roi = int(ys.min()), int(ys.max())

    # Load YOLO
    model = YOLO(model_path)

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Không mở được video: {video_path}")

    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps <= 0:
        fps = 25.0  # fallback
    frames_per_window = max(int(fps * window_sec), 1)

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    # Clamp ROI rect vào trong frame
    x_min = max(0, x_min_roi)
    y_min = max(0, y_min_roi)
    x_max = min(width, x_max_roi)
    y_max = min(height, y_max_roi)

    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    out = cv2.VideoWriter(overlay_path, fourcc, fps, (width, height))

    rows = []
    window_counts = defaultdict(int)
    frame_idx = 0
    window_index = 0

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    total_duration_sec = total_frames / fps if total_frames > 0 else 0

    # Trạng thái tracking theo ID
    # track_id -> {"cls": canonical_label, "last_inside": bool, "counted": bool}
    tracks_state = {}

    print(
        f"[VIDEO1911] fps={fps}, frames_per_window={frames_per_window}, "
        f"total_frames={total_frames}, roi_rect=({x_min},{y_min})-({x_max},{y_max})"
    )

    while True:
        ret, frame = cap.read()
        if not ret:
            # Khi video kết thúc: mọi ID còn lại coi như vừa rời khung hình
            for tid, st in list(tracks_state.items()):
                if (not st.get("counted")) and st.get("last_inside"):
                    canonical = st["cls"]
                    window_counts[canonical] += 1
                    st["counted"] = True

            # flush window cuối
            if sum(window_counts.values()) > 0:
                t_start = window_index * window_sec
                t_end = min(t_start + window_sec, total_duration_sec)
                row = {
                    "window": window_index,
                    "time_start_s": round(t_start, 2),
                    "time_end_s": round(t_end, 2),
                }
                for lbl in TARGET_LABELS:
                    row[lbl] = window_counts.get(lbl, 0)
                rows.append(row)
            break

        frame_idx += 1

        # copy riêng cho YOLO (không vẽ đè lên ảnh feed vào model)
        orig_frame = frame.copy()

        # vẽ ROI bán trong suốt lên frame hiển thị
        frame = _draw_roi_transparent(frame, roi_np, alpha=0.3)

        # CROP ROI cho YOLO xử lý
        roi_crop = orig_frame[y_min:y_max, x_min:x_max]
        if roi_crop.size == 0:
            out.write(frame)
            continue

        # TRACK thay vì chỉ detect
        results = model.track(
            roi_crop,
            conf=conf,
            iou=iou,
            persist=True,   # giữ ID giữa các frame
            verbose=False
        )[0]

        prev_ids = set(tracks_state.keys())
        current_ids = set()

        # ------------ cập nhật state từng ID ------------
        for box in results.boxes:
            if box.id is None:
                continue  # không có ID thì bỏ

            track_id = int(box.id[0])
            current_ids.add(track_id)

            cls_id = int(box.cls[0])
            conf_score = float(box.conf[0])
            raw_name = model.names[cls_id]
            label_name = raw_name.lower().strip()
            canonical = CLASS_CANONICAL_MAP.get(label_name)
            if canonical is None:
                continue

            x1, y1, x2, y2 = box.xyxy[0].tolist()
            x1, y1, x2, y2 = map(int, (x1, y1, x2, y2))

            # Đưa về toạ độ full-frame
            x1g = x1 + x_min
            y1g = y1 + y_min
            x2g = x2 + x_min
            y2g = y2 + y_min

            inside_now = _is_inside_roi(roi_np, x1g, y1g, x2g, y2g)

            state = tracks_state.get(
                track_id,
                {"cls": canonical, "last_inside": False, "counted": False},
            )
            state["cls"] = canonical
            state["last_inside"] = inside_now
            tracks_state[track_id] = state

            # Vẽ bbox cho dễ quan sát
            color = (0, 255, 0) if inside_now else (128, 128, 128)
            cv2.rectangle(frame, (x1g, y1g), (x2g, y2g), color, 2)
            cx = int((x1g + x2g) / 2)
            cy = int((y1g + y2g) / 2)
            cv2.circle(frame, (cx, cy), 3, (0, 255, 255), -1)
            txt = f"ID {track_id} {canonical} {conf_score:.2f}"
            cv2.putText(frame, txt, (x1g, max(y1g - 10, 0)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        # ------------ xác định ID nào vừa rời khung ------------
        ended_ids = prev_ids - current_ids
        for tid in ended_ids:
            st = tracks_state.get(tid)
            if st is None:
                continue
            if (not st.get("counted")) and st.get("last_inside"):
                canonical = st["cls"]
                window_counts[canonical] += 1  # ĐẾM 1 LẦN CHO ID NÀY
                st["counted"] = True
                print(f"[VIDEO1911] ID {tid} ({canonical}) counted in window {window_index}")
            # xoá để giải phóng bộ nhớ
            del tracks_state[tid]

        # ---- overlay thông tin thời gian + số lượng trong window hiện tại ---
        t_current_sec = frame_idx / fps
        overlay_text = f"t={t_current_sec:5.1f}s  window={window_index}"
        cv2.putText(frame, overlay_text, (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)

        y0 = 60
        dy = 25
        for lbl in TARGET_LABELS:
            txt = f"{lbl}: {window_counts.get(lbl, 0)}"
            cv2.putText(frame, txt, (10, y0),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
            y0 += dy

        out.write(frame)

        # ---------- kết thúc 1 window 5s ----------
        if frame_idx % frames_per_window == 0:
            t_start = window_index * window_sec
            t_end = min(t_start + window_sec, total_duration_sec)
            row = {
                "window": window_index,
                "time_start_s": round(t_start, 2),
                "time_end_s": round(t_end, 2),
            }
            print(f"[VIDEO1911] window={window_index} counts={dict(window_counts)}")
            for lbl in TARGET_LABELS:
                row[lbl] = window_counts.get(lbl, 0)
            rows.append(row)

            window_index += 1
            window_counts = defaultdict(int)

    cap.release()
    out.release()
    cv2.destroyAllWindows()

    # Ghi Excel
    if rows:
        df = pd.DataFrame(rows)
        Path(excel_path).parent.mkdir(parents=True, exist_ok=True)
        df.to_excel(excel_path, index=False)

    print(f"[VIDEO1911] done (ID-based + ROI crop). "
          f"windows={len(rows)}, excel={excel_path}, overlay={overlay_path}")

    return {
        "excel": excel_path,
        "overlay": overlay_path,
        "windows": len(rows),
    }


# ----------------------------------------------------------------------
# LIVE MODE – ID-BASED COUNTING + CROP ROI
# ----------------------------------------------------------------------
def run_counter_live_1911(
    cam_index: int,
    model_path: str,
    roi_points,
    excel_path: str,
    window_sec: int = 5,
    conf: float = 0.3,
    iou: float = 0.45,
    show_window: bool = True,
):
    """
    LIVE + ID-based counting + ROI crop:
    - YOLO chỉ xử lý vùng bounding box của ROI.
    - Mỗi vehicle (track_id) được đếm đúng 1 lần khi RỜI ROI.
    - Mỗi window_sec (5s) ghi 1 dòng Excel: time_start, time_end, bike/car/bus/truck.
    - Nhấn 'q' để dừng.
    """
    roi_np = np.array(roi_points, dtype=np.int32)
    xs = roi_np[:, 0]
    ys = roi_np[:, 1]
    x_min_roi, x_max_roi = int(xs.min()), int(xs.max())
    y_min_roi, y_max_roi = int(ys.min()), int(ys.max())

    model = YOLO(model_path)

    cap = cv2.VideoCapture(cam_index)
    if not cap.isOpened():
        raise RuntimeError(f"Không mở được camera index {cam_index}")

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    # clamp ROI
    x_min = max(0, x_min_roi)
    y_min = max(0, y_min_roi)
    x_max = min(width, x_max_roi)
    y_max = min(height, y_max_roi)

    rows = []
    window_counts = defaultdict(int)
    window_start = datetime.now()
    next_cut = window_start + timedelta(seconds=window_sec)

    Path(excel_path).parent.mkdir(parents=True, exist_ok=True)

    # track_id -> {"cls": canonical_label, "last_inside": bool, "counted": bool}
    tracks_state = {}

    print(
        f"Bắt đầu đếm live 1911 (ID-based + ROI crop). "
        f"ROI rect=({x_min},{y_min})-({x_max},{y_max})"
    )

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        orig_frame = frame.copy()
        frame = _draw_roi_transparent(frame, roi_np, alpha=0.3)

        # crop cho YOLO
        roi_crop = orig_frame[y_min:y_max, x_min:x_max]
        if roi_crop.size == 0:
            if show_window:
                cv2.imshow("Live YOLO Counting 1911 (ID-based, q=quit)", frame)
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
            continue

        # TRACK trong ROI
        results = model.track(
            roi_crop,
            conf=conf,
            iou=iou,
            persist=True,
            verbose=False
        )[0]

        prev_ids = set(tracks_state.keys())
        current_ids = set()

        # ---- Cập nhật state cho từng ID hiện tại ----
        for box in results.boxes:
            if box.id is None:
                continue

            track_id = int(box.id[0])
            current_ids.add(track_id)

            cls_id = int(box.cls[0])
            conf_score = float(box.conf[0])
            raw_name = model.names[cls_id]
            label_name = raw_name.lower().strip()
            canonical = CLASS_CANONICAL_MAP.get(label_name)
            if canonical is None:
                continue

            x1, y1, x2, y2 = box.xyxy[0].tolist()
            x1, y1, x2, y2 = map(int, (x1, y1, x2, y2))

            # map về toạ độ global
            x1g = x1 + x_min
            y1g = y1 + y_min
            x2g = x2 + x_min
            y2g = y2 + y_min

            inside_now = _is_inside_roi(roi_np, x1g, y1g, x2g, y2g)

            state = tracks_state.get(
                track_id,
                {"cls": canonical, "last_inside": False, "counted": False},
            )
            state["cls"] = canonical
            state["last_inside"] = inside_now
            tracks_state[track_id] = state

            # Vẽ bbox
            color = (0, 255, 0) if inside_now else (128, 128, 128)
            cv2.rectangle(frame, (x1g, y1g), (x2g, y2g), color, 2)
            cx = int((x1g + x2g) / 2)
            cy = int((y1g + y2g) / 2)
            cv2.circle(frame, (cx, cy), 3, (0, 255, 255), -1)
            txt = f"ID {track_id} {canonical} {conf_score:.2f}"
            cv2.putText(frame, txt, (x1g, max(y1g - 10, 0)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        # ---- ID nào vừa biến mất khỏi frame -> nếu trước đó ở trong ROI thì đếm ----
        ended_ids = prev_ids - current_ids
        for tid in ended_ids:
            st = tracks_state.get(tid)
            if st is None:
                continue
            if (not st.get("counted")) and st.get("last_inside"):
                canonical = st["cls"]
                window_counts[canonical] += 1
                st["counted"] = True
                print(f"[LIVE1911] ID {tid} ({canonical}) counted")
            del tracks_state[tid]

        # ---- Overlay thời gian + count hiện tại lên frame ----
        now = datetime.now()
        cv2.putText(frame, now.strftime("%Y-%m-%d %H:%M:%S"),
                    (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8,
                    (0, 255, 255), 2)

        y0 = 60
        dy = 25
        for lbl in TARGET_LABELS:
            txt = f"{lbl}: {window_counts.get(lbl, 0)}"
            cv2.putText(frame, txt, (10, y0),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                        (255, 255, 0), 2)
            y0 += dy

        if show_window:
            cv2.imshow("Live YOLO Counting 1911 (ID-based, q=quit)", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

        # ---- Kết thúc 1 window 5s -> ghi 1 dòng Excel ----
        if now >= next_cut:
            row = {
                "time_start": window_start.strftime("%Y-%m-%d %H:%M:%S"),
                "time_end": now.strftime("%Y-%m-%d %H:%M:%S"),
            }
            print(f"[LIVE1911] window {row['time_start']} -> {row['time_end']}, counts={dict(window_counts)}")

            for lbl in TARGET_LABELS:
                row[lbl] = window_counts.get(lbl, 0)
            rows.append(row)

            df = pd.DataFrame(rows)
            df.to_excel(excel_path, index=False)

            # reset bộ đếm, giữ tracks_state để tiếp tục theo dõi ID
            window_counts = defaultdict(int)
            window_start = now
            next_cut = window_start + timedelta(seconds=window_sec)

    cap.release()
    cv2.destroyAllWindows()

    # Nếu dừng giữa 1 window, ghi nốt phần còn lại
    if sum(window_counts.values()) > 0:
        now = datetime.now()
        row = {
            "time_start": window_start.strftime("%Y-%m-%d %H:%M:%S"),
            "time_end": now.strftime("%Y-%m-%d %H:%M:%S"),
        }
        for lbl in TARGET_LABELS:
            row[lbl] = window_counts.get(lbl, 0)
        rows.append(row)
        df = pd.DataFrame(rows)
        df.to_excel(excel_path, index=False)

    print(f"[LIVE1911] done (ID-based + ROI crop). windows={len(rows)}, excel={excel_path}")
    return {"excel": excel_path, "windows": len(rows)}
