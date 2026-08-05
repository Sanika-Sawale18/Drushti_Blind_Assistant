import os
import shutil

def convert():
    try:
        from ultralytics import YOLO
    except ImportError:
        print("ERROR: ultralytics not installed.")
        print("Run: pip install ultralytics")
        return

    pt_model_path = "yolov8n.pt"         

    print(f"Loading model: {pt_model_path}")
    model = YOLO(pt_model_path)

    print("Exporting to TFLite (float32, 640x640) ...")
    export_path = model.export(
        format="tflite",
        imgsz=640,
    )
    print(f"Export complete: {export_path}")

    tflite_file = None
    search_dir = str(export_path) if os.path.isdir(str(export_path)) else os.path.dirname(str(export_path))
    for root, _, files in os.walk(search_dir):
        for f in files:
            if f.endswith(".tflite"):
                tflite_file = os.path.join(root, f)
                break

    if not tflite_file:
        print("ERROR: Could not find .tflite output file.")
        print(f"Look in: {search_dir}")
        return

    dest = os.path.join("assets", "models", "yolomodel.tflite")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.copy2(tflite_file, dest)
    size_mb = os.path.getsize(dest) / (1024 * 1024)
    print(f"\n✅ Model saved to: {dest}  ({size_mb:.1f} MB)")
    print("You can now run: flutter run")


if __name__ == "__main__":
    convert()
