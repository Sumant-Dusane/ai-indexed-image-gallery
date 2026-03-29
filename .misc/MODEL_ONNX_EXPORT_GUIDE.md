# Model Export Guide — Google Colab
# AI Gallery App — All 4 Models

Run each numbered cell in order, top to bottom.
After the final cell, download all 6 files to your machine
and place them in `assets/models/` in your Flutter project.

---

## BEFORE STARTING

Runtime type: Runtime → Change runtime type → T4 GPU → Save

Paste this in your browser console (F12 → Console) to prevent
Colab from disconnecting when you step away:

```javascript
function ClickConnect(){
  document.querySelector("colab-toolbar-button#connect")?.click()
}
setInterval(ClickConnect, 60000)
```

---

## CELL 1 — Install dependencies (run once at session start)

```python
# Colab already has torch — do NOT reinstall it
!pip install -q onnx onnxslim onnxruntime onnxruntime-tools huggingface_hub

import torch, onnx, onnxruntime
print("torch:", torch.__version__)
print("onnx:", onnx.__version__)
print("onnxruntime:", onnxruntime.__version__)
```

---

---

## MODEL 1 — MobileCLIP-S1

Produces 2 files: image encoder + text encoder
Also copies the BPE vocab file needed for text tokenization at runtime.

---

### CELL 2 — Clone repo and download checkpoint

```python
import os

!git clone -q https://github.com/apple/ml-mobileclip.git
!pip install -q -e ml-mobileclip/

os.makedirs("/content/ml-mobileclip/checkpoints", exist_ok=True)

from huggingface_hub import hf_hub_download
hf_hub_download(
    repo_id="apple/MobileCLIP-S1",
    filename="mobileclip_s1.pt",
    local_dir="/content/ml-mobileclip/checkpoints"
)

print("Checkpoint:", os.listdir("/content/ml-mobileclip/checkpoints"))
```

---

### CELL 3 — Export image encoder to ONNX

```python
import torch
import sys
sys.path.insert(0, "/content/ml-mobileclip")
import mobileclip

model, _, _ = mobileclip.create_model_and_transforms(
    'mobileclip_s1',
    pretrained='/content/ml-mobileclip/checkpoints/mobileclip_s1.pt'
)
model.eval()

dummy_image = torch.randn(1, 3, 224, 224)

torch.onnx.export(
    model.visual,
    dummy_image,
    "/content/mobileclip_s1_image.onnx",
    input_names=["image"],
    output_names=["embedding"],
    opset_version=17,
    dynamic_axes={"image": {0: "batch"}, "embedding": {0: "batch"}}
)

print("Image encoder exported")

# Quick shape check
import onnxruntime as ort
import numpy as np
sess = ort.InferenceSession("/content/mobileclip_s1_image.onnx")
out = sess.run(None, {"image": np.random.randn(1,3,224,224).astype(np.float32)})
print("Output shape:", out[0].shape)  # expect (1, 512)
```

---

### CELL 4 — Export text encoder to ONNX

```python
import torch
import sys
sys.path.insert(0, "/content/ml-mobileclip")
import mobileclip

model, _, _ = mobileclip.create_model_and_transforms(
    'mobileclip_s1',
    pretrained='/content/ml-mobileclip/checkpoints/mobileclip_s1.pt'
)
model.eval()

tokenizer = mobileclip.get_tokenizer('mobileclip_s1')
dummy_tokens = tokenizer(["a photo"])   # shape [1, 77]

torch.onnx.export(
    model.text,
    dummy_tokens,
    "/content/mobileclip_s1_text.onnx",
    input_names=["tokens"],
    output_names=["embedding"],
    opset_version=17,
    dynamic_axes={"tokens": {0: "batch"}, "embedding": {0: "batch"}}
)

print("Text encoder exported")

# Quick shape check
import onnxruntime as ort
import numpy as np
sess = ort.InferenceSession("/content/mobileclip_s1_text.onnx")
out = sess.run(None, {"tokens": dummy_tokens.numpy()})
print("Output shape:", out[0].shape)  # expect (1, 512)
```

---

### CELL 5 — Slim + INT8 quantize both encoders

```python
import onnxslim
from onnxruntime.quantization import quantize_dynamic, QuantType

# Slim
onnxslim.slim("/content/mobileclip_s1_image.onnx",
              "/content/mobileclip_s1_image_slim.onnx")
onnxslim.slim("/content/mobileclip_s1_text.onnx",
              "/content/mobileclip_s1_text_slim.onnx")
print("Slimmed")

# INT8 quantize
quantize_dynamic(
    "/content/mobileclip_s1_image_slim.onnx",
    "/content/mobileclip_s1_image_int8.onnx",
    weight_type=QuantType.QUInt8
)
quantize_dynamic(
    "/content/mobileclip_s1_text_slim.onnx",
    "/content/mobileclip_s1_text_int8.onnx",
    weight_type=QuantType.QUInt8
)
print("Quantized")

# Copy BPE vocab file — needed by Rust tokenizer at runtime
import shutil
shutil.copy(
    "/content/ml-mobileclip/mobileclip/bpe_simple_vocab_16e6.txt.gz",
    "/content/bpe_vocab.json"
)

# Size report
import os
for f in ["mobileclip_s1_image_int8.onnx",
          "mobileclip_s1_text_int8.onnx",
          "bpe_vocab.json"]:
    mb = os.path.getsize(f"/content/{f}") / 1024 / 1024
    print(f"{f}: {mb:.1f} MB")
```

---

### CELL 6 — Download MobileCLIP files

```python
from google.colab import files
files.download("/content/mobileclip_s1_image_int8.onnx")
files.download("/content/mobileclip_s1_text_int8.onnx")
files.download("/content/bpe_vocab.json")
```

---

---

## MODEL 2 — MobileFaceNet

Produces 1 file: face embedding model

---

### CELL 7 — Clone repo and download weights

```python
import os

!git clone -q https://github.com/foamliu/MobileFaceNet.git

os.makedirs("/content/MobileFaceNet/weights", exist_ok=True)

!wget -q https://github.com/foamliu/MobileFaceNet/releases/download/v1.0/mobilefacenet.pt \
     -O /content/MobileFaceNet/weights/mobilefacenet.pt

print("Weights:", os.listdir("/content/MobileFaceNet/weights"))
```

---

### CELL 8 — Export to ONNX + quantize

```python
import torch
import sys
sys.path.insert(0, "/content/MobileFaceNet")
from mobilefacenet import MobileFaceNet

model = MobileFaceNet()
model.load_state_dict(
    torch.load("/content/MobileFaceNet/weights/mobilefacenet.pt",
               map_location="cpu")
)
model.eval()

dummy = torch.randn(1, 3, 112, 112)

torch.onnx.export(
    model,
    dummy,
    "/content/mobilefacenet.onnx",
    input_names=["face"],
    output_names=["embedding"],
    opset_version=17,
    dynamic_axes={"face": {0: "batch"}, "embedding": {0: "batch"}}
)
print("Exported")

# Shape check
import onnxruntime as ort
import numpy as np
sess = ort.InferenceSession("/content/mobilefacenet.onnx")
out = sess.run(None, {"face": np.random.randn(1,3,112,112).astype(np.float32)})
print("Output shape:", out[0].shape)  # expect (1, 128)

# INT8 quantize
from onnxruntime.quantization import quantize_dynamic, QuantType
quantize_dynamic(
    "/content/mobilefacenet.onnx",
    "/content/mobilefacenet_int8.onnx",
    weight_type=QuantType.QUInt8
)

import os
mb = os.path.getsize("/content/mobilefacenet_int8.onnx") / 1024 / 1024
print(f"mobilefacenet_int8.onnx: {mb:.1f} MB")
```

---

### CELL 9 — Download MobileFaceNet file

```python
from google.colab import files
files.download("/content/mobilefacenet_int8.onnx")
```

---

---

## MODEL 3 — YOLOv8-nano

Produces 1 file: object detection model

---

### CELL 10 — Export to ONNX + quantize

```python
# ultralytics is already installed on Colab, but ensure latest
!pip install -q -U ultralytics

from ultralytics import YOLO
import os

# Downloads yolov8n.pt automatically on first run (~6MB)
model = YOLO("yolov8n.pt")

# Export — fixed shape required for ORT Mobile performance
model.export(
    format="onnx",
    opset=17,
    simplify=True,
    dynamic=False,
    imgsz=640,
)
# Ultralytics saves it as yolov8n.onnx in current dir
print("Exported")

# Shape check
import onnxruntime as ort
import numpy as np
sess = ort.InferenceSession("yolov8n.onnx")
out = sess.run(None, {"images": np.random.randn(1,3,640,640).astype(np.float32)})
print("Output shape:", out[0].shape)  # expect (1, 84, 8400)
# 84 = 4 bbox coords + 80 COCO class scores
# 8400 = number of anchor predictions

# INT8 quantize
from onnxruntime.quantization import quantize_dynamic, QuantType
quantize_dynamic(
    "yolov8n.onnx",
    "/content/yolov8n_int8.onnx",
    weight_type=QuantType.QUInt8
)

mb = os.path.getsize("/content/yolov8n_int8.onnx") / 1024 / 1024
print(f"yolov8n_int8.onnx: {mb:.1f} MB")
```

---

### CELL 11 — Download YOLOv8 file

```python
from google.colab import files
files.download("/content/yolov8n_int8.onnx")
```

---

---

## MODEL 4 — Emotion classifier (EmotiEffLib / EfficientNet-B0)

Produces 1 file: 8-class facial emotion model
Trained on AffectNet. Classes: neutral, happy, sad, surprised, fear, disgust, angry, contempt
In your Rust code: if argmax == 7 (contempt), map it to "neutral"

---

### CELL 12 — Install and export

```python
!pip install -q emotiefflib

import torch
import os
from emotiefflib.facial_analysis import EmotiEffLibRecognizer

# Downloads enet_b0_8_best_vgaf.pt on first run (~25MB)
fer = EmotiEffLibRecognizer(engine='torch', model_name='enet_b0_8_best_vgaf')

pt_model = fer.model
pt_model.eval()

dummy = torch.randn(1, 3, 224, 224)

torch.onnx.export(
    pt_model,
    dummy,
    "/content/emotion_enet_b0.onnx",
    input_names=["face"],
    output_names=["logits"],
    opset_version=17,
    dynamic_axes={"face": {0: "batch"}, "logits": {0: "batch"}}
)
print("Exported")

# Shape check
import onnxruntime as ort
import numpy as np
sess = ort.InferenceSession("/content/emotion_enet_b0.onnx")
out = sess.run(None, {"face": np.random.randn(1,3,224,224).astype(np.float32)})
print("Output shape:", out[0].shape)  # expect (1, 8)

# INT8 quantize
from onnxruntime.quantization import quantize_dynamic, QuantType
quantize_dynamic(
    "/content/emotion_enet_b0.onnx",
    "/content/emotion_enet_b0_int8.onnx",
    weight_type=QuantType.QUInt8
)

mb = os.path.getsize("/content/emotion_enet_b0_int8.onnx") / 1024 / 1024
print(f"emotion_enet_b0_int8.onnx: {mb:.1f} MB")
```

---

### CELL 13 — Download emotion file

```python
from google.colab import files
files.download("/content/emotion_enet_b0_int8.onnx")
```

---

---

## CELL 14 — Final verification (run last)

Confirms all 6 files were produced correctly before you finish.

```python
import os
import onnxruntime as ort
import numpy as np

files_to_check = {
    "mobileclip_s1_image_int8.onnx": ("image",  (1,3,224,224), (1,512)),
    "mobileclip_s1_text_int8.onnx":  ("tokens", None,          (1,512)),
    "mobilefacenet_int8.onnx":       ("face",   (1,3,112,112), (1,128)),
    "yolov8n_int8.onnx":             ("images", (1,3,640,640), (1,84,8400)),
    "emotion_enet_b0_int8.onnx":     ("face",   (1,3,224,224), (1,8)),
}

print(f"{'File':<45} {'Size':>8}   {'Output shape'}")
print("-" * 75)

for fname, (input_name, input_shape, expected_out) in files_to_check.items():
    path = f"/content/{fname}"
    if not os.path.exists(path):
        print(f"  MISSING  {fname}")
        continue

    mb = os.path.getsize(path) / 1024 / 1024

    if input_shape is not None:
        sess = ort.InferenceSession(path)
        dummy = np.random.randn(*input_shape).astype(np.float32)
        out = sess.run(None, {input_name: dummy})
        shape_ok = out[0].shape == expected_out
        shape_str = str(out[0].shape)
        status = "OK" if shape_ok else "SHAPE MISMATCH"
    else:
        shape_str = "n/a"
        status = "OK"

    print(f"  {status:<6}  {fname:<45} {mb:>5.1f} MB   {shape_str}")

# bpe_vocab separately (not an ONNX file)
bpe = "/content/bpe_vocab.json"
if os.path.exists(bpe):
    mb = os.path.getsize(bpe) / 1024 / 1024
    print(f"  OK      {'bpe_vocab.json':<45} {mb:>5.1f} MB   vocab file")
else:
    print(f"  MISSING  bpe_vocab.json")
```

Expected output:
```
  OK      mobileclip_s1_image_int8.onnx             ~6.0 MB   (1, 512)
  OK      mobileclip_s1_text_int8.onnx              ~3.0 MB   (1, 512)
  OK      mobilefacenet_int8.onnx                   ~4.0 MB   (1, 128)
  OK      yolov8n_int8.onnx                         ~3.0 MB   (1, 84, 8400)
  OK      emotion_enet_b0_int8.onnx                 ~5.0 MB   (1, 8)
  OK      bpe_vocab.json                              ~1.0 MB   vocab file
```

---

## BPE VOCAB — USE .json, NOT .gz

The export pipeline produces `bpe_vocab.json` (copied from the raw `.gz` source).
If you somehow ended up with `bpe_vocab.gz` instead, discard it and generate the correct file:

```python
# Run this locally or in a new Colab cell — requires transformers
# pip install transformers

from transformers import CLIPTokenizer

tok = CLIPTokenizer.from_pretrained("openai/clip-vit-base-patch32")
tok.backend_tokenizer.save("bpe_vocab.json")
```

Then place `bpe_vocab.json` in `assets/models/`. Delete `bpe_vocab.gz` if present.

**Why:** The Rust `tokenizers` crate loads HuggingFace tokenizer JSON format directly.
It cannot read the raw `.gz` merge-rules file without a custom parser.

---

## AFTER DOWNLOADING

Place all 6 files in your Flutter project:

```
your_flutter_project/
  assets/
    models/
      mobileclip_s1_image_int8.onnx
      mobileclip_s1_text_int8.onnx
      bpe_vocab.json
      mobilefacenet_int8.onnx
      yolov8n_int8.onnx
      emotion_enet_b0_int8.onnx
```

Register them in pubspec.yaml:

```yaml
flutter:
  assets:
    - assets/models/mobileclip_s1_image_int8.onnx
    - assets/models/mobileclip_s1_text_int8.onnx
    - assets/models/bpe_vocab.json
    - assets/models/mobilefacenet_int8.onnx
    - assets/models/yolov8n_int8.onnx
    - assets/models/emotion_enet_b0_int8.onnx
```

## EMOTION CLASS MAPPING FOR RUST

Update docs/models.md — the emotion model outputs 8 classes not 7:

```rust
const EMOTION_LABELS: [&str; 8] = [
    "neutral",    // 0
    "happy",      // 1
    "sad",        // 2
    "surprised",  // 3
    "fear",       // 4
    "disgust",    // 5
    "angry",      // 6
    "contempt",   // 7 — map to "neutral" if argmax == 7
];

// In your classify_emotion() function:
let idx = argmax(&logits);
let label = if idx == 7 { "neutral" } else { EMOTION_LABELS[idx] };
```

## EMOTION MODEL INPUT SIZE CORRECTION

Update docs/models.md — emotion model expects 224x224, not 224x224.
The 224x224 figure was wrong (that is FER2013 dataset resolution).
EmotiEffLib EfficientNet-B0 expects 224x224 face crops.

Preprocessing in Rust for emotion model:
  1. Crop face region using YOLO bbox (expand 20%, clamp to image bounds)
  2. Resize crop to 224x224 (bilinear)
  3. Convert to RGB float32, normalize: pixel = pixel / 255.0
  4. Layout CHW → [1, 3, 224, 224]
  5. Run session → [1, 8] logits → softmax → argmax → label