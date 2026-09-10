# SIGH - Face Recognition Attendance System

**SIGH** is a real-time face recognition attendance system consisting of:

- **Backend:** Django + Django Channels with YuNet (face detection) and SFace (face recognition) powered by OpenCV DNN
- **Frontend:** Flutter multi-platform app (Android, iOS, Web, Windows, macOS, Linux) for live video streaming, attendance tracking, and roster management

---

## Project Structure

```
.
├── README.md
├── error.txt                           # Recent backend logs
├── sigh/                               # Flutter frontend
│   ├── lib/
│   │   ├── main.dart                   # App entry + live video stream page
│   │   ├── models/models.dart          # Shared data models
│   │   ├── services/api_service.dart   # REST API client
│   │   ├── theme/app_theme.dart        # Centralized UI theme
│   │   └── screens/
│   │       ├── dashboard_screen.dart
│   │       ├── sessions_screen.dart
│   │       ├── session_participants_screen.dart
│   │       ├── people_screen.dart
│   │       └── management_main_screen.dart
│   ├── pubspec.yaml
│   └── ...
└── sigh_backend_yunet/                 # Django backend
    ├── manage.py
    ├── requirements.txt
    ├── download_models.py
    ├── db.sqlite3
    ├── test.py
    ├── known_faces/
    ├── sigh_backend_yunet/             # Django project config
    │   ├── settings.py
    │   ├── asgi.py
    │   ├── routing.py
    │   └── urls.py
    └── test1_yunet/                    # Django app
        ├── models.py
        ├── face_streamer.py            # YuNet + SFace streaming logic
        ├── consumers.py                # WebSocket consumer
        ├── views.py
        ├── serializer.py
        └── urls.py
```

---

## Architecture

### Backend

- **Web framework:** Django 5.2 with Django REST Framework
- **Real-time layer:** Django Channels over WebSocket
- **ASGI server:** Daphne (development) / Uvicorn or Daphne (production)
- **Face detection:** YuNet (`face_detection_yunet_2023mar.onnx`)
- **Face recognition:** SFace (`face_recognition_sface_2021dec.onnx`) executed via `cv2.dnn` directly to avoid `FaceRecognizerSF` wrapper bugs in OpenCV 4.10
- **Database:** SQLite (`db.sqlite3`)

### Frontend

- **Framework:** Flutter 3.x with Dart 3.x
- **State management:** `provider`
- **HTTP client:** `http`
- **WebSocket client:** `web_socket_channel`

---

## Key Features

### Face Recognition Pipeline

- YuNet detects faces, including rotated and side-profile faces, in a single pass
- SFace produces 512-D embeddings using OpenCV DNN
- Cosine similarity is used for matching known faces
- Frames are streamed to connected Flutter clients over WebSocket

### Attendance Flow

1. Start the video stream from the Flutter app
2. Select or create a session
3. Recognized faces that are registered for that session are marked present
4. Attendance logs are written to the database (throttled to once per minute per person)

### Management Screens

- Dashboard with session and attendance stats
- Session management (create, list, delete)
- People management (register faces, roles)
- Session participants management
- Reports placeholder screen

---

## Backend API Overview

### REST Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET/POST | `/api/sessions/` | List or create sessions |
| GET/PUT/DELETE | `/api/sessions/{id}/` | Session details |
| GET/POST | `/api/people/` | List or create people |
| GET/PUT/DELETE | `/api/people/{id}/` | Person details |
| GET/POST | `/api/session-people/` | Session-person relations |
| GET/POST | `/api/sessions/{sid}/participants/` | List/add participants |
| DELETE | `/api/sessions/{sid}/participants/{pid}/` | Remove participant |
| GET | `/api/attendance-logs/` | Attendance log list |
| GET | `/api/dashboard/stats/` | Dashboard stats |

### WebSocket Messages

Connect to:

```
ws://127.0.0.1:8000/ws/stream/
```

Client-to-server message types:

- `register_face` — register a new face from a base64 image
- `set_session` — set the active session being tracked
- `get_sessions` — request the list of active sessions
- `get_session_participants` — request participants for a session

Server-to-client message types:

- `registration_result`
- `session_set_result`
- `sessions_list`
- `session_participants`
- `error`
- Binary JPEG frames

---

## Models

| Model | Purpose |
|-------|---------|
| `Session` | A class/event with name, description, active flag |
| `Person` | A registered person with name, role, and stored face encoding |
| `SessionPerson` | Links a person to a session with presence state and last-seen time |
| `AttendanceLog` | Timestamped attendance record for a person in a session |

Face encodings are stored as binary fields using pickle serialization of numpy arrays.

---

## Prerequisites

- Python 3.10+ for the backend
- Flutter SDK 3.9+ for the frontend
- Redis is configured in settings for Django Channels but can be bypassed in local dev if using Daphne in-process; check `CHANNEL_LAYERS` config if deployment requires it

---

## Backend Setup

### 1. Install dependencies

```bash
cd sigh_backend_yunet
python -m venv venv
# activate venv as appropriate for your OS
pip install -r requirements.txt
```

### 2. Download models

```bash
python download_models.py
```

This downloads:

- `test1_yunet/face_detection_yunet_2023mar.onnx`
- `test1_yunet/face_recognition_sface_2021dec.onnx`

### 3. Run migrations

```bash
python manage.py makemigrations test1_yunet
python manage.py migrate
```

### 4. Optional: create admin user

```bash
python manage.py createsuperuser
```

### 5. Start the server

Development:

```bash
python manage.py runserver
```

Production (example):

```bash
daphne -b 0.0.0.0 -p 8000 sigh_backend_yunet.asgi:application
```

---

## Frontend Setup

### 1. Install dependencies

```bash
cd sigh
flutter pub get
```

### 2. Configure backend URL

The API client is configured for:

```
http://127.0.0.1:8000/api
```

and the WebSocket client connects to:

```
ws://127.0.0.1:8000/ws/stream/
```

Edit `lib/services/api_service.dart` and the WebSocket URL in `lib/main.dart` if your backend runs on a different host or port.

### 3. Run the app

```bash
flutter run
```

Target platforms can be selected with standard Flutter platform flags (`-d chrome`, `-d android`, etc.).

---

## Known Issues / Notes

- There was a recent error log capturing `'numpy.int32' object is not iterable` and `'module 'django' has no attribute 'settings'` during face processing. These suggest either a model/OpenCV version interaction or Django settings not being configured before face_streamer initialization in some code paths. Check `error.txt` for the latest instance.
- SFace uses a different similarity scale than dlib-based approaches. The backend currently uses `FACE_SIMILARITY_THRESHOLD = 0.35` in settings and a `0.5` threshold in `verify_face`; adjust if matches are too strict or too loose for your environment.
- Camera index is hardcoded in `FaceStreamer.__init__` to `cv2.VideoCapture(1)`. Change it if your camera is on a different index.

---

## Deployment Notes

- Set `DEBUG = False` and replace `SECRET_KEY` before production use
- Configure `ALLOWED_HOSTS` and `CORS_ALLOWED_ORIGINS` for your frontend host
- Use a production ASGI server such as Daphne or Uvicorn with Gunicorn
- If Redis is used for channel layers, ensure it is running and accessible from the backend host

---

## License

MIT (same as the original project).
