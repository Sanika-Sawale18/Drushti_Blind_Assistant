# assets/models/

## Place your YOLOv8 TFLite model here

**Required file:** `yolomodel.tflite`

### How to get the model:

#### Option A – Convert from your existing YOLOv8 .pt file
```bash
# Install ultralytics (Python 3.8+)
pip install ultralytics

# Export to TFLite INT8 (best for mobile)
python -c "
from ultralytics import YOLO
model = YOLO('yolov8n.pt')          # use your .pt path
model.export(format='tflite', imgsz=640, int8=True)
"
# This creates: yolov8n_saved_model/yolov8n_float32.tflite  (or similar name)
# Rename it to: yolomodel.tflite  and place it in this folder
```

#### Option B – Download pre-exported model
A ready-to-use YOLOv8n TFLite model (COCO 80 classes, 640x640):
https://github.com/ultralytics/assets/releases/download/v8.2.0/yolov8n_float32.tflite

Rename it to `yolomodel.tflite`.

### Model input/output spec expected by this app:
- **Input:**  [1, 640, 640, 3]  float32, RGB, normalized 0–1
- **Output:** [1, 84, 8400]      float32 (4 bbox coords + 80 class scores)
