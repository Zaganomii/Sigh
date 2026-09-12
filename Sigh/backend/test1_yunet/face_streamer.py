"""
face_streamer.py - YuNet + SFace (via cv2.dnn) Implementation

Uses YuNet for face detection and OpenCV DNN directly for face recognition
to avoid FaceRecognizerSF wrapper bugs in OpenCV 4.10.

Key advantages:
1. YuNet handles heavy rotations and side profiles natively
2. Direct DNN usage avoids OpenCV 4.10 FaceRecognizerSF assertion bugs
3. Much faster on CPU than dlib's HOG + ResNet combination

IMPORTANT FIXES:
- v3: YuNet input size is DYNAMIC (matches incoming frame resolution).
- v3: SFace requires an ALIGNED 112x112 face. We use YuNet's 5 landmarks +
      cv2.estimateAffinePartial2D to warp to the canonical SFace template.
- v3: Embeddings are L2-normalized so cosine similarity == dot product.
- v4: Fixed YuNet output column layout. Each detected row has 15 columns:
        [0] x, [1] y, [2] w, [3] h,
        [4..13] = 5 (x, y) landmark pairs
                  order: right_eye, left_eye, nose, right_mouth, left_mouth
        [14] = detection score
      Previous code used face[4] for confidence and face[5:15] for landmarks,
      both off by one. That shuffled every landmark and silently broke the
      detector-confidence quality gate.
- v5: cv2.dnn.Net is NOT thread-safe. The recognizer's forward() pass is now
      serialized with a lock, because the streaming thread and the Django
      registration view both call into the same Net instance.
- v6: SFace preprocessing was wrong. The SFace ONNX graph has its own
      normalization baked in, so we must feed raw pixel values:
          scalefactor=1.0, mean=(0,0,0), swapRB=True
      The old [0,1] -> [-1,1] normalization double-normalized the input and
      collapsed embeddings so different identities scored ~0.8.
- v7: Alignment landmark mapping was wrong. OpenCV's FaceRecognizerSF
      uses an IDENTITY mapping from YuNet's 5 landmarks to SFACE_REFERENCE
      (the API names look swapped, but the pairing is positional). The old
      `lm[[1,0,2,4,3]]` swap horizontally mirrored every aligned crop,
      pushing distinct identities toward each other in embedding space.
"""

import cv2
import numpy as np
import os
import threading
import queue
import time
import json
import base64
import logging
import pickle
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from django.apps import apps
from django.utils import timezone

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# SFace canonical 5-point template for a 112x112 aligned face.
# Taken from OpenCV's modules/objdetect/src/face_recognize.cpp
#
# IMPORTANT: OpenCV's FaceRecognizerSF::alignCrop feeds YuNet's raw landmark
# block (face_mat[0, 4:14]) into this template with NO reordering, even
# though the API names for the two sides look "swapped". The pairing is
# positional: YuNet[0] <-> REF[0], YuNet[1] <-> REF[1], etc.
# ---------------------------------------------------------------------------
SFACE_REF_LANDMARKS = np.array([
    [38.2946, 51.6963],   # corresponds to YuNet landmark 0 (right_eye)
    [73.5318, 51.5014],   # corresponds to YuNet landmark 1 (left_eye)
    [56.0252, 71.7366],   # corresponds to YuNet landmark 2 (nose)
    [41.5493, 92.3655],   # corresponds to YuNet landmark 3 (right_mouth)
    [70.7299, 92.2041],   # corresponds to YuNet landmark 4 (left_mouth)
], dtype=np.float32)


class YuNetFaceDetector:
    """YuNet face detector - handles rotations and side profiles natively.

    The detector's input size is derived from the actual frame dimensions
    on every call, so no camera resolution needs to be known in advance.
    """

    def __init__(self, model_path=None, confidence_threshold=0.6):
        self.confidence_threshold = confidence_threshold
        self.model_path = None
        self.detector = None
        self._detector_input_size = None  # last size we set on the model
        self._load_model_path(model_path)

    # ------------------------------------------------------------------
    # Model loading
    # ------------------------------------------------------------------
    def _load_model_path(self, model_path=None):
        try:
            from django.conf import settings
            self.model_path = model_path or getattr(settings, 'YUNET_MODEL_PATH', None)
            if self.model_path and os.path.exists(self.model_path):
                pass
            else:
                self.model_path = self._download_yunet_model()
        except Exception:
            raise

    def _download_yunet_model(self):
        import urllib.request
        model_url = ("https://huggingface.co/opencv/face_detection_yunet/resolve/main/"
                     "face_detection_yunet_2023mar.onnx")
        model_path = os.path.join(
            os.path.dirname(__file__), "face_detection_yunet_2023mar.onnx"
        )
        if not os.path.exists(model_path) or os.path.getsize(model_path) < 10000:
            if os.path.exists(model_path):
                os.remove(model_path)
            os.makedirs(os.path.dirname(model_path), exist_ok=True)
            urllib.request.urlretrieve(model_url, model_path)
        return model_path

    # ------------------------------------------------------------------
    # Dynamic-size detector init / update
    # ------------------------------------------------------------------
    def _ensure_detector(self, w, h):
        """
        Create the detector on first use, or update its input size when the
        frame dimensions change (e.g. camera switch, resolution change,
        rotation fallback). No fixed input_size is hardcoded anywhere.
        """
        if w <= 0 or h <= 0:
            return False
        if self.detector is None:
            self.detector = cv2.FaceDetectorYN.create(
                model=self.model_path,
                config="",
                input_size=(w, h),
                score_threshold=self.confidence_threshold,
            )
            self._detector_input_size = (w, h)
            return True
        if self._detector_input_size != (w, h):
            self.detector.setInputSize((w, h))
            self._detector_input_size = (w, h)
        return True

    # ------------------------------------------------------------------
    # Detection
    # ------------------------------------------------------------------
    def detect_faces(self, frame, use_rotation_fallback=True):
        """Detect faces in a frame.

        Returns a list of dicts:
            {'bbox': (x, y, w, h), 'confidence': float,
             'landmarks': np.ndarray(10,) or None}
        Coordinates are in the SAME space as the input frame (no internal
        resize is performed anymore).

        YuNet per-row layout (15 columns):
            [0]=x, [1]=y, [2]=w, [3]=h,
            [4..13] = 5 (x, y) landmark pairs
                      order: right_eye, left_eye, nose,
                             right_mouth, left_mouth
            [14] = detection score
        """
        if self.model_path is None:
            return []

        h, w = frame.shape[:2]
        if not self._ensure_detector(w, h):
            return []

        results = self.detector.detect(frame)

        faces = []
        if results is None:
            pass
        else:
            faces_array = None
            if isinstance(results, np.ndarray):
                faces_array = results
            elif isinstance(results, tuple):
                candidates = [
                    r for r in results
                    if isinstance(r, np.ndarray) and r.ndim == 2 and r.shape[1] >= 5
                ]
                if candidates:
                    faces_array = candidates[0]

            if faces_array is not None and isinstance(faces_array, np.ndarray):
                for i in range(faces_array.shape[0]):
                    face = faces_array[i]
                    x, y, wf, hf = int(face[0]), int(face[1]), int(face[2]), int(face[3])

                    # Score is the LAST column (index 14), not index 4.
                    if faces_array.shape[1] >= 15:
                        confidence = float(face[14])
                    else:
                        confidence = float(face[4])

                    face_landmarks = None
                    if faces_array.shape[1] >= 14:
                        # 10 landmark values start at index 4 (right_eye x).
                        lm = face[4:14].reshape(5, 2).astype(np.float32)
                        face_landmarks = lm.flatten()

                    faces.append({
                        'bbox': (x, y, wf, hf),
                        'confidence': confidence,
                        'landmarks': face_landmarks,
                    })

        # Rotation fallback: only if NO faces detected and frame is portrait
        if use_rotation_fallback and len(faces) == 0 and h > w:
            try:
                rotated = cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)
                rh, rw = rotated.shape[:2]
                self._ensure_detector(rw, rh)  # rotated dims are swapped

                rot_results = self.detector.detect(rotated)

                rot_faces_array = None
                if rot_results is not None:
                    if isinstance(rot_results, np.ndarray):
                        rot_faces_array = rot_results
                    elif isinstance(rot_results, tuple):
                        candidates = [
                            r for r in rot_results
                            if isinstance(r, np.ndarray) and r.ndim == 2 and r.shape[1] >= 5
                        ]
                        if candidates:
                            rot_faces_array = candidates[0]

                if rot_faces_array is not None and isinstance(rot_faces_array, np.ndarray):
                    for i in range(rot_faces_array.shape[0]):
                        face = rot_faces_array[i]
                        x, y, wf, hf = int(face[0]), int(face[1]), int(face[2]), int(face[3])

                        # Same column layout fix here: score is at index 14.
                        if rot_faces_array.shape[1] >= 15:
                            confidence = float(face[14])
                        else:
                            confidence = float(face[4])

                        # Map bbox back to original frame coordinates
                        orig_x = y
                        orig_y = h - x - wf
                        orig_w = hf
                        orig_h = wf

                        faces.append({
                            'bbox': (orig_x, orig_y, orig_w, orig_h),
                            'confidence': confidence,
                            'landmarks': None,  # skip landmarks in rotated case
                        })

                # Restore the detector to the original orientation for next frame
                self._ensure_detector(w, h)
            except Exception:
                pass

        return faces


class SFaceRecognizer:
    """
    SFace face recognizer using OpenCV DNN directly.

    Uses cv2.dnn.readNetFromONNX to load the SFace model and performs
    inference directly, avoiding the FaceRecognizerSF wrapper which has
    known assertion bugs in OpenCV 4.10.

    Thread safety:
        cv2.dnn.Net is NOT thread-safe. The streaming loop and the Django
        request handler both call extract_embedding() on the same instance.
        A lock serializes setInput + forward so concurrent calls cannot
        corrupt each other's output.
    """

    def __init__(self, model_path=None):
        self.net = None
        self.model_path = model_path
        self._net_lock = threading.Lock()
        self._load_model(model_path)

    def _load_model(self, model_path=None):
        try:
            from django.conf import settings
            model_path = model_path or getattr(settings, 'RECOGNITION_MODEL_PATH', None)
            self.model_path = model_path

            if model_path and os.path.exists(model_path):
                self.net = cv2.dnn.readNetFromONNX(model_path)
            else:
                model_path = self._download_recognition_model()
                self.net = cv2.dnn.readNetFromONNX(model_path)
        except Exception:
            raise

    def _download_recognition_model(self):
        import urllib.request
        model_url = ("https://huggingface.co/opencv/face_recognition_sface/resolve/main/"
                     "face_recognition_sface_2021dec.onnx")
        model_name = "face_recognition_sface_2021dec.onnx"
        model_path = os.path.join(os.path.dirname(__file__), model_name)

        if not os.path.exists(model_path) or os.path.getsize(model_path) < 10000:
            if os.path.exists(model_path):
                os.remove(model_path)
            os.makedirs(os.path.dirname(model_path), exist_ok=True)
            urllib.request.urlretrieve(model_url, model_path)
        return model_path

    # ------------------------------------------------------------------
    # Alignment
    # ------------------------------------------------------------------
    @staticmethod
    def _align_face(frame, landmarks):
        """
        Warp the face to the canonical SFace 112x112 template using 5 landmarks.

        landmarks: flat array of 10 values from YuNet, in YuNet's native order:
                   [right_eye, left_eye, nose, right_mouth, left_mouth]

        Mapping to SFACE_REF_LANDMARKS is IDENTITY (no reordering) — this
        matches OpenCV's FaceRecognizerSF::alignCrop exactly. The API names
        on the two sides look "swapped" but the pairing is positional.

        Returns 112x112 BGR image, or None on failure.
        """
        try:
            lm = np.array(landmarks, dtype=np.float32).reshape(5, 2)

            # Identity mapping — see note in SFACE_REF_LANDMARKS above.
            src = lm

            M, _ = cv2.estimateAffinePartial2D(
                src, SFACE_REF_LANDMARKS, method=cv2.LMEDS
            )
            if M is None:
                return None

            aligned = cv2.warpAffine(
                frame, M, (112, 112),
                flags=cv2.INTER_LINEAR,
                borderMode=cv2.BORDER_CONSTANT,
                borderValue=(0, 0, 0)
            )
            return aligned
        except Exception:
            return None

    @staticmethod
    def _crop_resize(frame, bbox):
        """Fallback: crop with padding and resize. Only when landmarks missing."""
        try:
            x, y, w, h = bbox
            H, W = frame.shape[:2]
            pad = 0.2
            x1 = max(0, int(x - pad * w))
            y1 = max(0, int(y - pad * h))
            x2 = min(W, int(x + w + pad * w))
            y2 = min(H, int(y + h + pad * h))
            if x2 <= x1 or y2 <= y1:
                return None
            crop = frame[y1:y2, x1:x2]
            if crop.size == 0:
                return None
            return cv2.resize(crop, (112, 112))
        except Exception:
            return None

    # ------------------------------------------------------------------
    # Embedding
    # ------------------------------------------------------------------
    def extract_embedding(self, frame, bbox, landmarks=None):
        """
        Extract an L2-normalized SFace embedding.

        Prefers landmark-based alignment. Falls back to crop+resize when
        landmarks are unavailable (rotation fallback path).
        """
        if self.net is None:
            return None

        try:
            aligned = None
            if landmarks is not None and len(landmarks) == 10:
                aligned = self._align_face(frame, landmarks)

            if aligned is None:
                aligned = self._crop_resize(frame, bbox)
            if aligned is None:
                return None

            # Reject degenerate alignments (a collapsed warp would otherwise
            # produce a meaningless but reproducible embedding).
            if float(aligned.std()) < 10.0:
                return None

            # CRITICAL: SFace's ONNX graph has its own normalization baked in.
            # Feed RAW pixel values — scalefactor=1.0, mean=(0,0,0).
            # Pre-normalizing to [-1,1] double-normalizes and collapses the
            # embedding space so different identities score ~0.8.
            blob = cv2.dnn.blobFromImage(
                aligned,
                scalefactor=1.0,
                size=(112, 112),
                mean=(0, 0, 0),
                swapRB=True,
                crop=False
            )

            # Serialize net access: cv2.dnn.Net is not thread-safe.
            with self._net_lock:
                self.net.setInput(blob)
                embedding = self.net.forward().flatten().astype(np.float32)

            norm = np.linalg.norm(embedding)
            if norm == 0:
                return None
            return embedding / norm

        except Exception:
            return None

    def compute_similarity(self, embedding1, embedding2):
        """Cosine similarity. With L2-normalized embeddings this is just dot()."""
        try:
            e1 = embedding1.astype(np.float32)
            e2 = embedding2.astype(np.float32)
            n1 = np.linalg.norm(e1)
            n2 = np.linalg.norm(e2)
            if n1 == 0 or n2 == 0:
                return 0.0
            sim = float(np.dot(e1, e2) / (n1 * n2))
            return max(-1.0, min(1.0, sim))
        except Exception:
            return 0.0

    def verify_face(self, face_embedding, known_faces, threshold=None,
                    detector_confidence=None, margin=0.05):
        """
        Verify a face against known faces.

        Returns (matched_name, best_score) or (None, best_score) if rejected.
        """
        if threshold is None:
            try:
                from django.conf import settings
                threshold = getattr(settings, 'FACE_SIMILARITY_THRESHOLD', 0.65)
            except Exception:
                threshold = 0.65

        # Reject low-quality detections outright.
        if detector_confidence is not None and detector_confidence < 0.7:
            return None, 0.0

        if not known_faces:
            return None, 0.0

        scores = []
        for name, known_embedding in known_faces:
            scores.append((name, self.compute_similarity(face_embedding, known_embedding)))

        scores.sort(key=lambda t: t[1], reverse=True)
        best_name, best_score = scores[0]

        # Debug: uncomment to see raw similarity numbers per frame.
        # for n, s in scores:
        #     logger.warning("verify: %s -> %.4f (det_conf=%.3f)", n, s, detector_confidence or -1)

        if len(scores) == 1:
            # No second-best to provide margin, so demand a stricter absolute score.
            single_floor = max(threshold, 0.75)
            if best_score >= single_floor:
                return best_name, best_score
            return None, best_score

        second_score = scores[1][1]
        if best_score >= threshold and (best_score - second_score) >= margin:
            return best_name, best_score
        return None, best_score


class FaceStreamer:
    """Main face streaming class using YuNet + SFace (cv2.dnn)."""

    ATTENDANCE_LOG_INTERVAL = 60  # seconds

    def __init__(self):

        try:
            from django.conf import settings
            detection_threshold = getattr(settings, 'YUNET_FACE_THRESHOLD', 0.7)
        except Exception:
            detection_threshold = 0.7

        # NOTE: no input_size passed - the detector adopts the frame's size.
        self.detector = YuNetFaceDetector(
            confidence_threshold=detection_threshold
        )

        self.recognizer = SFaceRecognizer()

        # Threading locks
        self.processing_lock = threading.Lock()
        self.frame_lock = threading.Lock()
        self.registration_lock = threading.Lock()

        # Attendance throttle
        self._last_attendance_log = {}

        # Camera setup - resolution is best-effort, whatever the camera grants us.
        try:
            self.cap = cv2.VideoCapture(1)
            if not self.cap.isOpened():
                raise Exception("Could not open camera")
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            self.cap.set(cv2.CAP_PROP_FPS, 15)
        except Exception:
            raise

        # Threading
        self.frame_queue = queue.Queue(maxsize=1)
        self.running = False

        self.channel_layer = get_channel_layer()
        self.group_name = "video_stream"

        self._current_frame = None
        self._current_encodings = []

        # DB models
        self.Session = apps.get_model('test1_yunet', 'Session')
        self.Person = apps.get_model('test1_yunet', 'Person')
        self.SessionPerson = apps.get_model('test1_yunet', 'SessionPerson')
        self.AttendanceLog = apps.get_model('test1_yunet', 'AttendanceLog')

        self.current_session_id = None
        self.current_session = None

        # Encoding cache
        self._encodings_cache = ([], [], [])
        self._encodings_cache_time = 0.0
        self._encodings_cache_ttl = 30.0

        # Stream settings
        self.stream_fps = 15
        self.jpeg_quality = 60
        self._last_send_time = 0.0
        self._fps = 0.0
        self._fps_frame_count = 0
        self._fps_start_time = time.time()

    # ------------------------------------------------------------------
    # Known-faces cache
    # ------------------------------------------------------------------
    def load_known_faces_from_db(self):
        if time.time() - self._encodings_cache_time < self._encodings_cache_ttl:
            return self._encodings_cache

        with self.processing_lock:
            try:
                persons = self.Person.objects.all()
                known_encodings = []
                known_names = []
                known_roles = []

                for person in persons:
                    try:
                        if not person.face_encoding:
                            continue
                        encoding = pickle.loads(person.face_encoding)
                        known_encodings.append(encoding)
                        known_names.append(person.name)
                        known_roles.append(person.role)
                    except Exception as e:
                        logger.error(f"Error loading encoding for {person.name}: {e}")
                        continue

                self._encodings_cache = (known_encodings, known_names, known_roles)
                self._encodings_cache_time = time.time()
                return self._encodings_cache
            except Exception:
                return [], [], []

    # ------------------------------------------------------------------
    # Registration
    # ------------------------------------------------------------------
    def register_face(self, face_data, name, role):
        """Register a new face in the database."""
        try:
            face_bytes = base64.b64decode(face_data)
            nparr = np.frombuffer(face_bytes, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

            if img is None:
                return False

            h, w = img.shape[:2]
            if h > w * 1.1:
                img = cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)

            # Detect at native resolution (no scaling needed anywhere).
            faces = self.detector.detect_faces(img)
            if not faces:
                return False

            best_face = max(faces, key=lambda f: f['confidence'])

            # --- Enrollment quality gates -----------------------------------
            # Reject low-confidence detections.
            if best_face['confidence'] < 0.85:
                return False

            x, y, w, h = best_face['bbox']
            H, W = img.shape[:2]

            # Reject tiny faces (weak embeddings).
            if (w * h) < 0.05 * (W * H):
                return False

            # Require landmarks so alignment actually runs.
            landmarks = best_face.get('landmarks')
            if landmarks is None or len(landmarks) != 10:
                return False
            # ----------------------------------------------------------------

            encoding = self.recognizer.extract_embedding(
                img, (x, y, w, h), landmarks
            )
            if encoding is None:
                return False

            # Sanity-check the final vector.
            if encoding.shape[0] != 128 or float(np.std(encoding)) < 0.02:
                return False

            encoding_bytes = pickle.dumps(encoding)

            with self.registration_lock:
                person, created = self.Person.objects.get_or_create(
                    name=name,
                    defaults={'role': role, 'face_encoding': encoding_bytes}
                )
                if not created:
                    person.role = role
                    person.face_encoding = encoding_bytes
                    person.save()
                self._encodings_cache_time = 0.0

            return True
        except Exception:
            return False

    # ------------------------------------------------------------------
    # Attendance / sessions
    # ------------------------------------------------------------------
    def mark_attendance(self, person_name, session_id=None):
        try:
            if session_id is None:
                session_id = self.current_session_id
            if not session_id:
                return False

            now = time.time()
            key = (session_id, person_name)
            if key in self._last_attendance_log:
                last_time = self._last_attendance_log[key]
                if now - last_time < self.ATTENDANCE_LOG_INTERVAL:
                    person = self.Person.objects.get(name=person_name)
                    session = self.Session.objects.get(id=session_id)
                    session_person, _ = self.SessionPerson.objects.get_or_create(
                        session=session,
                        person=person,
                        defaults={'is_present': True, 'last_seen': timezone.now()}
                    )
                    session_person.is_present = True
                    session_person.last_seen = timezone.now()
                    session_person.save()
                    return True

            person = self.Person.objects.get(name=person_name)
            session = self.Session.objects.get(id=session_id)

            session_person, created = self.SessionPerson.objects.get_or_create(
                session=session,
                person=person,
                defaults={'is_present': True, 'last_seen': timezone.now()}
            )
            if not created:
                session_person.is_present = True
                session_person.last_seen = timezone.now()
                session_person.save()

            self.AttendanceLog.objects.create(session=session, person=person)
            self._last_attendance_log[key] = now
            return True
        except Exception:
            return False

    def get_session_participants(self, session_id=None):
        try:
            if session_id is None:
                session_id = self.current_session_id
            session = self.Session.objects.get(id=session_id)
            participants = self.SessionPerson.objects.filter(
                session=session
            ).select_related('person')

            return [{
                'name': sp.person.name,
                'role': sp.person.role,
                'is_present': sp.is_present,
                'last_seen': sp.last_seen.isoformat() if sp.last_seen else None
            } for sp in participants]
        except Exception:
            return []

    def set_current_session(self, session_id):
        try:
            self.current_session = self.Session.objects.get(id=session_id, is_active=True)
            self.current_session_id = session_id
            return True
        except self.Session.DoesNotExist:
            return False

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------
    def start(self):
        if not self.running:
            self.running = True
            threading.Thread(target=self.camera_reader, daemon=True).start()
            threading.Thread(target=self.face_processor, daemon=True).start()

    def stop(self):
        if self.running:
            self.running = False
            if self.cap.isOpened():
                self.cap.release()
            cv2.destroyAllWindows()

    def camera_reader(self):
        while self.running:
            try:
                if self.cap.isOpened():
                    ret, frame = self.cap.read()
                    if ret:
                        if self.frame_queue.empty():
                            self.frame_queue.put(frame)
                    else:
                        time.sleep(0.1)
                else:
                    time.sleep(1)
            except Exception:
                time.sleep(0.1)
            time.sleep(0.033)

    def face_processor(self):
        while self.running:
            try:
                if not self.frame_queue.empty():
                    frame = self.frame_queue.get()

                    with self.frame_lock:
                        self._current_frame = frame.copy()

                    processed_frame = self.process_frame(frame)

                    if processed_frame is not None:
                        self.send_frame(processed_frame)

                    self._fps_frame_count += 1
                    elapsed = time.time() - self._fps_start_time
                    if elapsed >= 1.0:
                        self._fps = self._fps_frame_count / elapsed
                        self._fps_frame_count = 0
                        self._fps_start_time = time.time()
            except Exception:
                time.sleep(0.01)

    # ------------------------------------------------------------------
    # Per-frame processing
    # ------------------------------------------------------------------
    def process_frame(self, frame):
        try:
            # Detect at native resolution (no scaling happens anymore).
            faces = self.detector.detect_faces(frame)

            with self.frame_lock:
                self._current_encodings.clear()

            known_encodings, known_names, known_roles = self.load_known_faces_from_db()

            for face_info in faces:
                bbox = face_info['bbox']
                landmarks = face_info.get('landmarks')

                try:
                    encoding = self.recognizer.extract_embedding(
                        frame, bbox, landmarks
                    )
                    if encoding is None:
                        continue

                    with self.frame_lock:
                        self._current_encodings.append(encoding)

                    name = "Unknown"
                    role = "Unknown Role"
                    is_in_session = False

                    if known_encodings:
                        known_faces = list(zip(known_names, known_encodings))
                        detector_conf = face_info.get('confidence', 0.0)
                        matched_name, similarity = self.recognizer.verify_face(
                            encoding, known_faces,
                            detector_confidence=detector_conf
                        )

                        # Debug: uncomment to see per-frame match decisions.
                        # logger.info("[DEBUG] best_score=%.3f matched=%s",
                        #             similarity, matched_name)

                        if matched_name:
                            name = matched_name
                            role_idx = known_names.index(name)
                            role = (known_roles[role_idx]
                                    if role_idx < len(known_roles) else "Unknown Role")

                            if self.current_session_id:
                                session_participants = [
                                    p['name'] for p in self.get_session_participants()
                                ]
                                is_in_session = name in session_participants
                                # Always refresh attendance for a recognised person
                                self.mark_attendance(name)

                    # Draw
                    x, y, w, h = bbox
                    color = (0, 255, 0) if is_in_session else (0, 0, 255)

                    cv2.rectangle(frame, (x, y), (x + w, y + h), color, 2)

                    status_text = f"{name} - {role}"
                    cv2.putText(frame, status_text, (x, y - 10),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

                    if landmarks is not None and len(landmarks) == 10:
                        for i in range(0, 10, 2):
                            lx = int(landmarks[i])
                            ly = int(landmarks[i + 1])
                            cv2.circle(frame, (lx, ly), 2, (0, 255, 255), -1)
                except Exception:
                    continue

            # FPS overlay
            cv2.putText(frame, f"FPS: {self._fps:.1f}", (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)

            return frame
        except Exception:
            return frame

    def send_frame(self, frame):
        try:
            now = time.time()
            min_interval = 1.0 / max(self.stream_fps, 1)
            if now - self._last_send_time < min_interval:
                return
            self._last_send_time = now

            _, jpeg = cv2.imencode(
                ".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, self.jpeg_quality]
            )
            async_to_sync(self.channel_layer.group_send)(
                self.group_name,
                {"type": "send_frame", "bytes_data": jpeg.tobytes()}
            )
        except Exception:
            pass