"""
face_streamer.py - YuNet + SFace (via cv2.dnn) Implementation

Uses YuNet for face detection and OpenCV DNN directly for face recognition
to avoid FaceRecognizerSF wrapper bugs in OpenCV 4.10.

Key advantages:
1. YuNet handles heavy rotations and side profiles natively
2. Direct DNN usage avoids OpenCV 4.10 FaceRecognizerSF assertion bugs
3. Much faster on CPU than dlib's HOG + ResNet combination
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

class YuNetFaceDetector:
    """YuNet face detector - handles rotations and side profiles natively."""
    
    def __init__(self, model_path=None, input_size=320, confidence_threshold=0.6):
        self.input_size = input_size
        self.confidence_threshold = confidence_threshold
        self.model_path = None
        self.detector = None  # Will be initialized lazily on first use
        self._load_model_path(model_path)
    
    def _load_model_path(self, model_path=None):
        """Get the model path without loading the detector."""
        try:
            from django.conf import settings
            self.model_path = model_path or getattr(settings, 'YUNET_MODEL_PATH', None)
            
            if self.model_path and os.path.exists(self.model_path):
                pass
            else:
                self.model_path = self._download_yunet_model()
        except Exception as e:
            raise
    
    def _download_yunet_model(self):
        """Download YuNet model."""
        import urllib.request
        model_url = "https://huggingface.co/opencv/face_detection_yunet/resolve/main/face_detection_yunet_2023mar.onnx"
        model_path = os.path.join(os.path.dirname(__file__), "face_detection_yunet_2023mar.onnx")
        
        if not os.path.exists(model_path) or os.path.getsize(model_path) < 10000:
            if os.path.exists(model_path):
                os.remove(model_path)
            os.makedirs(os.path.dirname(model_path), exist_ok=True)
            urllib.request.urlretrieve(model_url, model_path)
        
        return model_path
    
    def _init_detector(self, frame_width, frame_height):
        """Create detector once with a fixed input size. Reuse on subsequent calls."""
        if self.detector is None:
            # Use a fixed square input size to avoid dimension mismatch issues
            # YuNet works best with 320x320 or similar fixed sizes
            w = h = self.input_size
            self.detector = cv2.FaceDetectorYN.create(
                model=self.model_path,
                config="",
                input_size=(w, h),
                score_threshold=self.confidence_threshold
            )
            self.detector.setInputSize((w, h))
    
    def detect_faces(self, frame, use_rotation_fallback=True):
        """Detect faces in a frame.
        
        FIX: Reuse a single detector instance to avoid OpenCV internal state corruption.
        
        FIX: Robustly extract faces array from the return tuple.
        
        Args:
            frame: Input image (BGR format)
            use_rotation_fallback: If True, tries 90-degree rotation when no faces found
            
        Returns:
            List of detected faces with bounding boxes
        """
        if self.model_path is None:
            return []
        
        h, w = frame.shape[:2]
        
        # Initialize detector once (lazy initialization)
        self._init_detector(w, h)
        
        # Resize frame to detector's fixed input size for consistency
        # This avoids dimension mismatch errors and ensures stable detection
        detector_w, detector_h = self.detector.getInputSize()
        if (w, h) != (detector_w, detector_h):
            frame = cv2.resize(frame, (detector_w, detector_h))
            h, w = detector_h, detector_w
        
        results = self.detector.detect(frame)
        
        faces = []
        if results is None:
            pass  # Try rotation fallback below
        else:
            # Robust extraction of faces array
            faces_array = None
            if isinstance(results, np.ndarray):
                faces_array = results
            elif isinstance(results, tuple):
                # Find the element that is an Nx15 (or at least 5 columns) ndarray
                candidates = [
                    r for r in results
                    if isinstance(r, np.ndarray) and r.ndim == 2 and r.shape[1] >= 5
                ]
                if candidates:
                    faces_array = candidates[0]
            
            if faces_array is not None and isinstance(faces_array, np.ndarray):
                # faces_array is Nx15: each row: x,y,w,h,confidence, and 5 landmarks (x1,y1,...)
                for i in range(faces_array.shape[0]):
                    face = faces_array[i]
                    x, y, wf, hf = int(face[0]), int(face[1]), int(face[2]), int(face[3])
                    confidence = float(face[4])
                    
                    # Extract landmarks from columns 5-14 if present
                    face_landmarks = None
                    if faces_array.shape[1] >= 15:
                        lm = face[5:15].reshape(5, 2).astype(np.int32)
                        face_landmarks = lm.flatten()
                    
                    faces.append({
                        'bbox': (x, y, wf, hf),
                        'confidence': confidence,
                        'landmarks': face_landmarks
                    })
        
        # Rotation fallback: only if NO faces detected and frame is portrait
        if use_rotation_fallback and len(faces) == 0 and h > w:
            try:
                rotated = cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)
                rot_results = self.detector.detect(rotated)
                
                if rot_results is not None:
                    rot_faces_array = None
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
                            confidence = float(face[4])
                            
                            # Map bbox back to original frame coordinates
                            # After 90cw rotation: (x,y) in rotated -> (y, h-x-w) in original
                            orig_x = y
                            orig_y = h - x - wf
                            orig_w = hf
                            orig_h = wf
                            
                            # Landmarks are skipped for fallback to avoid incorrect mapping
                            faces.append({
                                'bbox': (orig_x, orig_y, orig_w, orig_h),
                                'confidence': confidence,
                                'landmarks': None
                            })
            except Exception as e:
                pass
        
        return faces


class SFaceRecognizer:
    """
    SFace face recognizer using OpenCV DNN directly.
    
    Uses cv2.dnn.readNetFromONNX to load the SFace model and performs
    inference directly, avoiding the FaceRecognizerSF wrapper which has
    known assertion bugs in OpenCV 4.10.
    """
    
    def __init__(self, model_path=None):
        self.net = None
        self.model_path = model_path
        self._load_model(model_path)
    
    def _load_model(self, model_path=None):
        """Load SFace model using cv2.dnn directly."""
        try:
            from django.conf import settings
            model_path = model_path or getattr(settings, 'RECOGNITION_MODEL_PATH', None)
            self.model_path = model_path
            
            if model_path and os.path.exists(model_path):
                # Load using cv2.dnn directly - avoids FaceRecognizerSF bugs
                self.net = cv2.dnn.readNetFromONNX(model_path)
            else:
                model_path = self._download_recognition_model()
                self.net = cv2.dnn.readNetFromONNX(model_path)
        except Exception as e:
            raise
    
    def _download_recognition_model(self):
        """Download SFace model from Hugging Face."""
        import urllib.request
        model_url = "https://huggingface.co/opencv/face_recognition_sface/resolve/main/face_recognition_sface_2021dec.onnx"
        model_name = "face_recognition_sface_2021dec.onnx"
        model_path = os.path.join(os.path.dirname(__file__), model_name)
        
        if not os.path.exists(model_path) or os.path.getsize(model_path) < 10000:
            if os.path.exists(model_path):
                os.remove(model_path)
            os.makedirs(os.path.dirname(model_path), exist_ok=True)
            urllib.request.urlretrieve(model_url, model_path)
        
        return model_path
    
    def extract_embedding(self, frame, bbox, landmarks=None):
        """
        Extract face embedding using SVFLite-style face recognition.
        
        The SFace model expects a 112x112 aligned face as input.
        We'll crop and resize the face, then run inference through the network.
        """
        if self.net is None:
            return None
        
        x, y, w, h = bbox
        
        try:
            # Crop the face region with some padding
            h_frame, w_frame = frame.shape[:2]
            pad = 0.2
            x1 = max(0, int(x - pad * w))
            y1 = max(0, int(y - pad * h))
            x2 = min(w_frame, int(x + w + pad * w))
            y2 = min(h_frame, int(y + h + pad * h))
            
            if x2 <= x1 or y2 <= y1:
                return None
            
            face_crop = frame[y1:y2, x1:x2]
            if face_crop.size == 0:
                return None
            
            # Resize to 112x112 (SFace input size)
            face_resized = cv2.resize(face_crop, (112, 112))
            
            # Create blob for DNN inference
            # SFace expects BGR input normalized to [-1, 1] or [0, 1]
            blob = cv2.dnn.blobFromImage(
                face_resized,
                scalefactor=1.0/127.5,
                size=(112, 112),
                mean=(127.5, 127.5, 127.5),
                swapRB=True,  # BGR to RGB
                crop=False
            )
            
            # Run inference
            self.net.setInput(blob)
            embedding = self.net.forward()
            
            # Flatten to 1D array (512-D for SFace)
            embedding = embedding.flatten()
            
            return embedding
            
        except Exception as e:
            return None
    
    def compute_similarity(self, embedding1, embedding2):
        """
        Compute cosine similarity between two embeddings.
        
        SFace produces 512-D embeddings. We use cosine similarity.
        """
        try:
            # Ensure float32
            emb1 = embedding1.astype(np.float32)
            emb2 = embedding2.astype(np.float32)
            
            # Normalize embeddings
            norm1 = np.linalg.norm(emb1)
            norm2 = np.linalg.norm(emb2)
            
            if norm1 == 0 or norm2 == 0:
                return 0.0
            
            # Cosine similarity
            similarity = np.dot(emb1, emb2) / (norm1 * norm2)
            
            # Clamp to [-1, 1]
            return float(max(-1.0, min(1.0, similarity)))
            
        except Exception as e:
            return 0.0
    
    def verify_face(self, face_embedding, known_faces, threshold=None):
        """
        Verify if a face matches any known face.
        
        Args:
            face_embedding: Embedding of detected face
            known_faces: List of (name, embedding) tuples
            threshold: Cosine similarity cutoff. Defaults to Django
                       FACE_SIMILARITY_THRESHOLD (0.6 for SFace).
            
        Returns:
            Tuple of (matched_name, similarity_score) or (None, 0) if no match
        """
        if threshold is None:
            try:
                from django.conf import settings
                threshold = getattr(settings, 'FACE_SIMILARITY_THRESHOLD', 0.6)
            except Exception:
                threshold = 0.6
        
        if not known_faces:
            return None, 0.0
        
        best_match = None
        best_score = -1.0
        
        for name, known_embedding in known_faces:
            similarity = self.compute_similarity(face_embedding, known_embedding)
            if similarity > best_score:
                best_score = similarity
                best_match = name
        
        # Cosine similarity is in [-1, 1]. 1.0 = identical.
        if best_score >= threshold:
            return best_match, best_score
        
        return None, best_score


class FaceStreamer:
    """Main face streaming class using YuNet + SFace (cv2.dnn)."""
    
    # Throttle interval for attendance logging (seconds)
    ATTENDANCE_LOG_INTERVAL = 60  # log at most once per minute per person
    
    def __init__(self):
        
        # Initialize YuNet face detector
        # Use 320x320 as the model input size (this is what the model was trained on)
        # The setInputSize() call in detect_faces() will handle the actual frame size
        # Fix 3: Lower confidence threshold for live video
        # Try 0.3 first - if still no detection, may need to check lighting/position
        self.detector = YuNetFaceDetector(
            input_size=320,
            confidence_threshold=0.3  # Aggressively lower threshold for live video
        )
        
        # Initialize SFace face recognizer (using cv2.dnn directly)
        self.recognizer = SFaceRecognizer()
        
        # Threading locks
        self.processing_lock = threading.Lock()
        self.frame_lock = threading.Lock()
        self.registration_lock = threading.Lock()
        
        # Attendance log throttle dictionary: key=(session_id, person_name) -> last log time
        self._last_attendance_log = {}
        
        # Camera setup
        try:
            self.cap = cv2.VideoCapture(1)
            if not self.cap.isOpened():
                raise Exception("Could not open camera")
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            self.cap.set(cv2.CAP_PROP_FPS, 15)
        except Exception as e:
            raise
        
        # Threading setup
        self.frame_queue = queue.Queue(maxsize=1)
        self.running = False
        
        self.channel_layer = get_channel_layer()
        self.group_name = "video_stream"
        
        self._current_frame = None
        self._current_encodings = []
        
        # Database models
        self.Session = apps.get_model('test1_yunet', 'Session')
        self.Person = apps.get_model('test1_yunet', 'Person')
        self.SessionPerson = apps.get_model('test1_yunet', 'SessionPerson')
        self.AttendanceLog = apps.get_model('test1_yunet', 'AttendanceLog')
        
        self.current_session_id = None
        self.current_session = None
        
        # Frame counter for saving debug samples (disabled for production)
        # self._frame_counter = 0
        
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
        

    
    def load_known_faces_from_db(self):
        """Load known faces from database with caching."""
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
            except Exception as e:
                return [], [], []
    
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
            
            # Don't resize - let detect_faces handle the native resolution
            faces = self.detector.detect_faces(img)
            
            if not faces:
                return False
            
            best_face = max(faces, key=lambda f: f['confidence'])
            
            # Compute scaling factors from original img to detector input size
            orig_h, orig_w = img.shape[:2]
            detector_w, detector_h = self.detector.detector.getInputSize()
            scale_x = orig_w / detector_w
            scale_y = orig_h / detector_h
            
            x, y, w, h = best_face['bbox']
            scaled_bbox = (int(x * scale_x), int(y * scale_y), int(w * scale_x), int(h * scale_y))
            
            # Extract embedding using the scaled bbox on the original image
            encoding = self.recognizer.extract_embedding(img, scaled_bbox, None)
            
            if encoding is None:
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
        except Exception as e:
            return False
    
    def mark_attendance(self, person_name, session_id=None):
        """
        Mark a person as present in the current session.
        Throttled to avoid duplicate logs: only creates an AttendanceLog entry if
        the last log for this person in this session is older than ATTENDANCE_LOG_INTERVAL.
        """
        try:
            if session_id is None:
                session_id = self.current_session_id
                
            if not session_id:
                return False
            
            # Throttle check
            now = time.time()
            key = (session_id, person_name)
            if key in self._last_attendance_log:
                last_time = self._last_attendance_log[key]
                if now - last_time < self.ATTENDANCE_LOG_INTERVAL:
                    # Too soon; skip creating a new AttendanceLog, but still update presence
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
            
            # Proceed with normal logging
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
            # Update throttle timestamp
            self._last_attendance_log[key] = now
            return True
        except Exception as e:
            return False
    
    def get_session_participants(self, session_id=None):
        """Get all participants for a session."""
        try:
            if session_id is None:
                session_id = self.current_session_id
                
            session = self.Session.objects.get(id=session_id)
            participants = self.SessionPerson.objects.filter(session=session).select_related('person')
            
            return [{
                'name': sp.person.name,
                'role': sp.person.role,
                'is_present': sp.is_present,
                'last_seen': sp.last_seen.isoformat() if sp.last_seen else None
            } for sp in participants]
        except Exception as e:
            return []
    
    def set_current_session(self, session_id):
        """Set the current session."""
        try:
            self.current_session = self.Session.objects.get(id=session_id, is_active=True)
            self.current_session_id = session_id
            return True
        except self.Session.DoesNotExist:
            return False
    
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
                        # Don't force resize - let YuNet handle native camera resolution
                        # This preserves aspect ratio and avoids face distortion
                        if self.frame_queue.empty():
                            self.frame_queue.put(frame)
                    else:
                        time.sleep(0.1)
                else:
                    time.sleep(1)
            except Exception as e:
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

            except Exception as e:
                time.sleep(0.01)
    
    def process_frame(self, frame):
        try:
            # Store original frame dimensions before resizing
            orig_h, orig_w = frame.shape[:2]
            
            # Detect faces (frame will be resized internally to 320x320)
            faces = self.detector.detect_faces(frame)
            
            with self.frame_lock:
                self._current_encodings.clear()
            
            known_encodings, known_names, known_roles = self.load_known_faces_from_db()
            
            # Compute scaling factors from original frame to detector input size
            detector_w, detector_h = self.detector.detector.getInputSize()
            scale_x = orig_w / detector_w
            scale_y = orig_h / detector_h
            
            for face_info in faces:
                bbox = face_info['bbox']
                landmarks = face_info.get('landmarks')
                
                # Scale bbox back to original frame size BEFORE extracting embedding
                x, y, w, h = bbox
                scaled_bbox = (int(x * scale_x), int(y * scale_y), int(w * scale_x), int(h * scale_y))
                
                try:
                    encoding = self.recognizer.extract_embedding(frame, scaled_bbox, landmarks)
                    
                    if encoding is None:
                        continue
                    
                    with self.frame_lock:
                        self._current_encodings.append(encoding)
                    
                    name = "Unknown"
                    role = "Unknown Role"
                    is_in_session = False
                    if known_encodings:
                        known_faces = list(zip(known_names, known_encodings))
                        matched_name, similarity = self.recognizer.verify_face(
                            encoding, known_faces
                        )
                        
                        if matched_name:
                            name = matched_name
                            role_idx = known_names.index(name)
                            role = known_roles[role_idx] if role_idx < len(known_roles) else "Unknown Role"
                            
                            if self.current_session_id:
                                session_participants = [p['name'] for p in self.get_session_participants()]
                                is_in_session = name in session_participants
                                
                                if is_in_session:
                                    self.mark_attendance(name)
                    
                    # For drawing, we can reuse the scaled bbox
                    x, y, w, h = scaled_bbox
                    
                    color = (0, 255, 0) if is_in_session else (0, 0, 255)
                    
                    cv2.rectangle(frame, (x, y), (x + w, y + h), color, 2)
                    
                    status_text = f"{name} - {role}"
                    if self.current_session_id:
                        status_text += " " if is_in_session else " "
                    
                    cv2.putText(frame, status_text, (x, y - 10),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)
                    
                    if landmarks is not None:
                        # Scale landmarks back to original frame size
                        scaled_landmarks = []
                        for i in range(0, len(landmarks), 2):
                            lx = int(landmarks[i] * scale_x)
                            ly = int(landmarks[i+1] * scale_y)
                            scaled_landmarks.extend([lx, ly])
                            cv2.circle(frame, (lx, ly), 2, (0, 255, 255), -1)
                    # Draw FPS on frame
                    cv2.putText(frame, f"FPS: {self._fps:.1f}", (10, 30),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                except Exception as e:
                    continue
            
            return frame
        except Exception as e:
            return frame
    
    def send_frame(self, frame):
        try:
            now = time.time()
            min_interval = 1.0 / max(self.stream_fps, 1)
            if now - self._last_send_time < min_interval:
                return
            self._last_send_time = now

            _, jpeg = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, self.jpeg_quality])
            async_to_sync(self.channel_layer.group_send)(
                self.group_name,
                {"type": "send_frame", "bytes_data": jpeg.tobytes()}
            )
        except Exception as e:
            pass