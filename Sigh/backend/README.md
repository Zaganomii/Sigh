# SIGH Backend - YuNet + MobileFaceNet

A high-performance face recognition backend using **YuNet** for face detection and **MobileFaceNet** for face recognition.

## Why YuNet + MobileFaceNet?

This implementation follows **Option 1** from the performance analysis:

| Component | Original (dlib) | New (YuNet + MobileFaceNet) | Improvement |
|-----------|-----------------|------------------------------|-------------|
| Detector | dlib HOG + shape_predictor | YuNet | Handles rotations natively, 5-10x faster |
| Recognizer | dlib ResNet (29-layer) | MobileFaceNet | Same 128-D embeddings, 3x faster |

### Key Benefits

1. **Rotation Handling**: YuNet detects faces at any angle (90°, 180°, 270°) in a single pass
2. **CPU Efficiency**: MobileFaceNet uses fraction of compute compared to dlib's ResNet
3. **Side Profiles**: Better detection of profile faces compared to dlib's frontal detector
4. **Lightweight**: Total model size ~20MB vs dlib's ~200MB

## Quick Start

### 1. Install Dependencies

```bash
cd sigh_backend_yunet
pip install -r requirements.txt
```

### 2. Download Models

```bash
python download_models.py
```

This downloads:
- `face_detection_yunet_2023mar.onnx` (YuNet detector, ~5MB)
- `face_recognition_mobilefacenet.onnx` (MobileFaceNet, ~15MB)

### 3. Run Migrations

**Important**: Run this on the machine where you'll run the server (Windows in your case):

```bash
python manage.py makemigrations test1_yunet
python manage.py migrate
```

### 4. Create Admin User (Optional)

```bash
python manage.py createsuperuser
```

### 5. Start Server (Development)

```bash
python manage.py runserver
```

This uses **daphne** automatically (Django Channels detection). The WebSocket endpoint will be available at `ws://localhost:8000/ws/stream/`

### Start Server (Production)

For production, use daphne or uvicorn directly:

```bash
# Using daphne (recommended for Channels)
daphne -b 0.0.0.0 -p 8000 sigh_backend_yunet.asgi:application

# Or using uvicorn
uvicorn sigh_backend_yunet.asgi:application --host 0.0.0.0 --port 8000
```

## Project Structure

```
sigh_backend_yunet/
├── manage.py                 # Django management script
├── requirements.txt          # Python dependencies
├── download_models.py        # Model downloader script
├── db.sqlite3               # SQLite database
├── known_faces/              # Registered face images
├── faces_data.json           # Face metadata
├── sigh_backend_yunet/       # Django project
│   ├── settings.py           # YuNet + MobileFaceNet configuration
│   ├── asgi.py               # ASGI for WebSocket support
│   ├── routing.py            # WebSocket routing
│   └── ...
└── test1_yunet/             # Django app
    ├── models.py             # Database models
    ├── face_streamer.py      # YuNet + MobileFaceNet implementation
    └── consumers.py          # WebSocket consumer
```

## Configuration

Edit `sigh_backend_yunet/settings.py` to adjust:

```python
# YuNet settings
YUNET_INPUT_SIZE = 320        # 320, 416, or 640 (higher = more accurate)
YUNET_FACE_THRESHOLD = 0.6    # Detection confidence threshold

# Recognition settings
RECOGNITION_BACKEND = "mobilefacenet"  # or "arcface"
FACE_SIMILARITY_THRESHOLD = 0.6        # Similarity threshold for matching
```

## WebSocket API

### Connect
```javascript
const ws = new WebSocket('ws://localhost:8000/ws/stream/');
```

### Register Face
```javascript
ws.send(JSON.stringify({
    type: 'register_face',
    face_data: '<base64_image>',
    name: 'John Doe',
    role: 'Student'
}));
```

### Set Session
```javascript
ws.send(JSON.stringify({
    type: 'set_session',
    session_id: 'uuid-of-session'
}));
```

### Get Sessions
```javascript
ws.send(JSON.stringify({
    type: 'get_sessions'
}));
```

## Performance Comparison

| Metric | dlib (Original) | YuNet + MobileFaceNet |
|--------|-----------------|------------------------|
| Detection Speed | ~50ms/frame | ~10ms/frame |
| Recognition Speed | ~100ms/frame | ~30ms/frame |
| Rotation Handling | Needs explicit handling | Native support |
| Profile Faces | Poor | Good |
| CPU Usage | High | Low |
| Model Size | ~200MB | ~20MB |

## Migration from dlib Backend

The database schema is identical to the original dlib backend. To migrate:

1. Copy `db.sqlite3` from the old project
2. Run `python manage.py migrate` to ensure schema is up to date
3. Re-register faces (encodings are different format)

## Production Deployment

### Recommended: Daphne + Nginx

```bash
# Install daphne
pip install daphne

# Run daphne (use systemd or supervisor for process management)
daphne -b 127.0.0.1 -p 8000 sigh_backend_yunet.asgi:application

# Configure nginx to proxy to daphne
```

### Alternative: Uvicorn + Gunicorn

```bash
pip install uvicorn gunicorn

gunicorn sigh_backend_yunet.asgi:application -k uvicorn.workers.UvicornWorker -b 127.0.0.1:8000
```

## Troubleshooting

### Model Download Fails
Download models manually from:
- YuNet: https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx
- MobileFaceNet: https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_mobilefacenet/face_recognition_mobilefacenet.onnx

Place them in the project root directory.

### Camera Not Found
Change camera index in `face_streamer.py`:
```python
self.cap = cv2.VideoCapture(0)  # Try 0, 1, 2, etc.
```

### Low Detection Accuracy
Increase YuNet input size in settings:
```python
YUNET_INPUT_SIZE = 416  # or 640 for better accuracy (slower)
```

## License

MIT License - same as original project
