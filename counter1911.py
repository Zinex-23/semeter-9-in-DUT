import torch
import time  # Dùng cho chế độ Live

# ====== FIX CHO PYTORCH 2.6 ======
_orig_torch_load = torch.load
def _torch_load_legacy(*args, **kwargs):
    kwargs.setdefault("weights_only", False)
    return _orig_torch_load(*args, **kwargs)
torch.load = _torch_load_legacy
# =================================

from ultralytics import YOLO
import cv2
import numpy as np
import pandas as pd
from collections import defaultdict
from pathlib import Path
from datetime import datetime, timedelta

# --- CẤU HÌNH KẸT XE (TRAFFIC JAM) ---
# Nếu một xe ở trong ROI quá số giây này -> coi là bị kẹt/chậm
JAM_DURATION_THRESHOLD = 4.5  # Giây

# Nếu số lượng xe bị kẹt/chậm vượt quá số này -> Báo động TRAFFIC JAM
JAM_VEHICLE_COUNT_THRESHOLD = 5 

TARGET_LABELS = ("bike", "car", "bus", "truck")

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
    cx = (x1 + x2) / 2.0
    cy = (y1 + y2) / 2.0
    inside = cv2.pointPolygonTest(roi_np, (cx, cy), False)
    return inside >= 0

def _draw_roi_transparent(frame, roi_np, alpha: float = 0.3, color_poly=(0, 255, 0)):
    """Vẽ ROI. color_poly: màu viền (xanh lá nếu bình thường, đỏ nếu kẹt xe)"""
    overlay = frame.copy()
    # Fill màu đỏ nhạt
    cv2.fillPoly(overlay, [roi_np], color=(0, 0, 255))
    frame = cv2.addWeighted(overlay, alpha, frame, 1 - alpha, 0)
    # Viền thay đổi theo trạng thái
    cv2.polylines(frame, [roi_np], isClosed=True, color=color_poly, thickness=3)
    return frame

# ----------------------------------------------------------------------
# VIDEO MODE
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
    video_path = str(video_path)
    excel_path = str(excel_path)
    overlay_path = str(overlay_path)

    roi_np = np.array(roi_points, dtype=np.int32)
    xs, ys = roi_np[:, 0], roi_np[:, 1]
    x_min_roi, x_max_roi = int(xs.min()), int(xs.max())
    y_min_roi, y_max_roi = int(ys.min()), int(ys.max())

    model = YOLO(model_path)
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Không mở được video: {video_path}")

    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps <= 0: fps = 25.0
    frames_per_window = max(int(fps * window_sec), 1)

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    # Clamp ROI
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
    
    current_window_status = "Normal" 

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    total_duration_sec = total_frames / fps if total_frames > 0 else 0

    tracks_state = {}

    print(f"[VIDEO1911] Start. Jam Threshold: >{JAM_VEHICLE_COUNT_THRESHOLD} cars stay >{JAM_DURATION_THRESHOLD}s")

    while True:
        ret, frame = cap.read()
        if not ret:
            # Flush data cuối
            if sum(window_counts.values()) > 0:
                t_start = window_index * window_sec
                t_end = min(t_start + window_sec, total_duration_sec)
                row = {
                    "window": window_index,
                    "time_start_s": round(t_start, 2),
                    "time_end_s": round(t_end, 2),
                    "status": current_window_status
                }
                for lbl in TARGET_LABELS:
                    row[lbl] = window_counts.get(lbl, 0)
                rows.append(row)
            break

        frame_idx += 1
        current_video_time = frame_idx / fps

        orig_frame = frame.copy()
        roi_crop = orig_frame[y_min:y_max, x_min:x_max]
        
        # Track
        if roi_crop.size > 0:
            results = model.track(roi_crop, conf=conf, iou=iou, persist=True, verbose=False)[0]
        else:
            results = None

        prev_ids = set(tracks_state.keys())
        current_ids = set()
        
        stuck_vehicles_count = 0

        if results:
            for box in results.boxes:
                if box.id is None: continue
                track_id = int(box.id[0])
                current_ids.add(track_id)
                
                cls_id = int(box.cls[0])
                conf_score = float(box.conf[0])
                canonical = CLASS_CANONICAL_MAP.get(model.names[cls_id].lower().strip())
                if not canonical: continue

                x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
                x1g, y1g, x2g, y2g = x1 + x_min, y1 + y_min, x2 + x_min, y2 + y_min
                
                inside_now = _is_inside_roi(roi_np, x1g, y1g, x2g, y2g)
                
                state = tracks_state.get(track_id, {
                    "cls": canonical, 
                    "last_inside": False, 
                    "counted": False,
                    "entry_time_video": None 
                })
                
                if inside_now:
                    if state["entry_time_video"] is None:
                        state["entry_time_video"] = current_video_time
                    
                    duration_in_roi = current_video_time - state["entry_time_video"]
                    
                    if duration_in_roi > JAM_DURATION_THRESHOLD:
                        stuck_vehicles_count += 1
                        
                    color = (0, 255, 0) # Xanh lá
                    if duration_in_roi > JAM_DURATION_THRESHOLD:
                        color = (0, 165, 255) # Cam
                        
                    cv2.rectangle(frame, (x1g, y1g), (x2g, y2g), color, 2)
                    txt = f"{canonical} {duration_in_roi:.1f}s"
                    cv2.putText(frame, txt, (x1g, max(y1g - 10, 0)),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
                else:
                    state["entry_time_video"] = None

                state["cls"] = canonical
                state["last_inside"] = inside_now
                tracks_state[track_id] = state

        # Xử lý đếm khi biến mất
        ended_ids = prev_ids - current_ids
        for tid in ended_ids:
            st = tracks_state.get(tid)
            if st and (not st.get("counted")) and st.get("last_inside"):
                window_counts[st["cls"]] += 1
                st["counted"] = True
            del tracks_state[tid]

        # --- KIỂM TRA TÌNH TRẠNG KẸT XE ---
        is_traffic_jam = stuck_vehicles_count >= JAM_VEHICLE_COUNT_THRESHOLD
        
        if is_traffic_jam:
            current_window_status = "Traffic Jam"

        # --- VẼ GIAO DIỆN ---
        poly_color = (0, 0, 255) if is_traffic_jam else (0, 255, 0)
        frame = _draw_roi_transparent(frame, roi_np, alpha=0.3, color_poly=poly_color)

        t_current_sec = frame_idx / fps
        cv2.putText(frame, f"t={t_current_sec:5.1f}s", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)

        if is_traffic_jam:
            # == FIX LỖI FONT ==
            cv2.rectangle(frame, (5, 40), (350, 100), (0, 0, 0), -1) 
            # Thay FONT_HERSHEY_BOLD bằng FONT_HERSHEY_SIMPLEX với độ dày 3
            cv2.putText(frame, "TRAFFIC JAM!", (10, 85),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 255), 3) 
            cv2.putText(frame, f"Stuck vehicles: {stuck_vehicles_count}", (10, 120),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 1)
        else:
            y0 = 60
            dy = 25
            for lbl in TARGET_LABELS:
                txt = f"{lbl}: {window_counts.get(lbl, 0)}"
                cv2.putText(frame, txt, (10, y0),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
                y0 += dy

        out.write(frame)

        if frame_idx % frames_per_window == 0:
            t_start = window_index * window_sec
            t_end = min(t_start + window_sec, total_duration_sec)
            row = {
                "window": window_index,
                "time_start_s": round(t_start, 2),
                "time_end_s": round(t_end, 2),
                "status": current_window_status 
            }
            for lbl in TARGET_LABELS:
                row[lbl] = window_counts.get(lbl, 0)
            rows.append(row)

            print(f"[VIDEO1911] Win {window_index}: {dict(window_counts)} | Status: {current_window_status}")
            
            window_index += 1
            window_counts = defaultdict(int)
            current_window_status = "Normal"

    cap.release()
    out.release()
    cv2.destroyAllWindows()

    if rows:
        df = pd.DataFrame(rows)
        Path(excel_path).parent.mkdir(parents=True, exist_ok=True)
        df.to_excel(excel_path, index=False)

    return {"excel": excel_path, "overlay": overlay_path, "windows": len(rows)}


# ----------------------------------------------------------------------
# LIVE MODE
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
    roi_np = np.array(roi_points, dtype=np.int32)
    xs, ys = roi_np[:, 0], roi_np[:, 1]
    x_min_roi, x_max_roi = int(xs.min()), int(xs.max())
    y_min_roi, y_max_roi = int(ys.min()), int(ys.max())

    model = YOLO(model_path)
    cap = cv2.VideoCapture(cam_index)
    if not cap.isOpened(): raise RuntimeError(f"Lỗi cam index {cam_index}")
    
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    x_min, x_max = max(0, x_min_roi), min(width, x_max_roi)
    y_min, y_max = max(0, y_min_roi), min(height, y_max_roi)

    rows = []
    window_counts = defaultdict(int)
    window_start = datetime.now()
    next_cut = window_start + timedelta(seconds=window_sec)
    current_window_status = "Normal"

    Path(excel_path).parent.mkdir(parents=True, exist_ok=True)
    
    tracks_state = {}

    print(f"[LIVE1911] Start. Jam Config: >{JAM_VEHICLE_COUNT_THRESHOLD} vehicles >{JAM_DURATION_THRESHOLD}s")

    while True:
        ret, frame = cap.read()
        if not ret: break

        orig_frame = frame.copy()
        roi_crop = orig_frame[y_min:y_max, x_min:x_max]
        
        current_ts = time.time() 

        if roi_crop.size > 0:
            results = model.track(roi_crop, conf=conf, iou=iou, persist=True, verbose=False)[0]
        else:
            results = None
            
        prev_ids = set(tracks_state.keys())
        current_ids = set()
        stuck_vehicles_count = 0

        if results:
            for box in results.boxes:
                if box.id is None: continue
                track_id = int(box.id[0])
                current_ids.add(track_id)
                
                cls_id = int(box.cls[0])
                canonical = CLASS_CANONICAL_MAP.get(model.names[cls_id].lower().strip())
                if not canonical: continue

                x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
                x1g, y1g, x2g, y2g = x1 + x_min, y1 + y_min, x2 + x_min, y2 + y_min
                inside_now = _is_inside_roi(roi_np, x1g, y1g, x2g, y2g)

                state = tracks_state.get(track_id, {
                    "cls": canonical, "last_inside": False, "counted": False, "entry_time_ts": None
                })

                if inside_now:
                    if state["entry_time_ts"] is None:
                        state["entry_time_ts"] = current_ts
                    
                    duration = current_ts - state["entry_time_ts"]
                    
                    if duration > JAM_DURATION_THRESHOLD:
                        stuck_vehicles_count += 1

                    color = (0, 255, 0)
                    if duration > JAM_DURATION_THRESHOLD:
                        color = (0, 165, 255) 
                        
                    cv2.rectangle(frame, (x1g, y1g), (x2g, y2g), color, 2)
                    cv2.putText(frame, f"{canonical} {duration:.1f}s", (x1g, max(y1g - 10, 0)),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
                else:
                    state["entry_time_ts"] = None
                
                state["cls"] = canonical
                state["last_inside"] = inside_now
                tracks_state[track_id] = state

        ended_ids = prev_ids - current_ids
        for tid in ended_ids:
            st = tracks_state.get(tid)
            if st and (not st.get("counted")) and st.get("last_inside"):
                window_counts[st["cls"]] += 1
                st["counted"] = True
            del tracks_state[tid]

        # --- KIỂM TRA KẸT XE LIVE ---
        is_traffic_jam = stuck_vehicles_count >= JAM_VEHICLE_COUNT_THRESHOLD
        if is_traffic_jam:
            current_window_status = "Traffic Jam"

        poly_color = (0, 0, 255) if is_traffic_jam else (0, 255, 0)
        frame = _draw_roi_transparent(frame, roi_np, alpha=0.3, color_poly=poly_color)

        now = datetime.now()
        cv2.putText(frame, now.strftime("%H:%M:%S"), (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)

        if is_traffic_jam:
            # == FIX LỖI FONT ==
            cv2.rectangle(frame, (5, 40), (350, 100), (0, 0, 0), -1)
            cv2.putText(frame, "TRAFFIC JAM!", (10, 85),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 255), 3)
            cv2.putText(frame, f"Stuck: {stuck_vehicles_count} vehicles", (10, 120),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 1)
        else:
            y0 = 60
            for lbl in TARGET_LABELS:
                txt = f"{lbl}: {window_counts.get(lbl, 0)}"
                cv2.putText(frame, txt, (10, y0), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
                y0 += 25

        if show_window:
            cv2.imshow("Live 1911", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'): break

        if now >= next_cut:
            row = {
                "time_start": window_start.strftime("%Y-%m-%d %H:%M:%S"),
                "time_end": now.strftime("%Y-%m-%d %H:%M:%S"),
                "status": current_window_status
            }
            for lbl in TARGET_LABELS: row[lbl] = window_counts.get(lbl, 0)
            rows.append(row)
            
            df = pd.DataFrame(rows)
            df.to_excel(excel_path, index=False)
            print(f"[LIVE] Saved. Status: {current_window_status}")

            window_counts = defaultdict(int)
            window_start = now
            next_cut = window_start + timedelta(seconds=window_sec)
            current_window_status = "Normal"

    cap.release()
    cv2.destroyAllWindows()
    if sum(window_counts.values()) > 0:
        row = {
            "time_start": window_start.strftime("%H:%M:%S"),
            "time_end": datetime.now().strftime("%H:%M:%S"),
            "status": current_window_status
        }
        for lbl in TARGET_LABELS: row[lbl] = window_counts.get(lbl, 0)
        rows.append(row)
        pd.DataFrame(rows).to_excel(excel_path, index=False)

    return {"excel": excel_path, "windows": len(rows)}