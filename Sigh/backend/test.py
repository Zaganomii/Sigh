"""
test_rotation.py - Check YuNet detection on original and rotated images (90, 180, 270 deg)

Run from the project root:
    python test_rotation.py [image_path]

It loads the YuNet model, detects faces in the original image and each rotation,
prints results, and saves annotated images.
"""

import sys
import os
import cv2

# --- Config ---------------------------------------------------------------
MODEL_PATH = os.path.join("test1_yunet", "face_detection_yunet_2023mar.onnx")
INPUT_IMAGE = sys.argv[1] if len(sys.argv) > 1 else "debug_frame_100.jpg"
CONFIDENCE_THRESHOLD = 0.6
# ---------------------------------------------------------------------------


def rotate_image(img, angle):
    """Rotate image by 0, 90, 180, or 270 degrees using cv2.rotate."""
    if angle == 0:
        return img
    elif angle == 90:
        return cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    elif angle == 180:
        return cv2.rotate(img, cv2.ROTATE_180)
    elif angle == 270:
        return cv2.rotate(img, cv2.ROTATE_90_COUNTERCLOCKWISE)
    else:
        raise ValueError("Angle must be 0, 90, 180, or 270")


def detect_faces(detector, img):
    """Run detection and return faces array (or None)."""
    results = detector.detect(img)
    if results is not None and isinstance(results, tuple) and len(results) == 2:
        return results[1]   # faces array
    return None


def annotate_and_save(img, faces_array, out_path):
    """Draw boxes and save image."""
    if faces_array is not None and faces_array.ndim == 2:
        for i in range(faces_array.shape[0]):
            face = faces_array[i]
            x, y, fw, fh = int(face[0]), int(face[1]), int(face[2]), int(face[3])
           
            confidence = float(face[14])  
            cv2.rectangle(img, (x, y), (x + fw, y + fh), (0, 255, 0), 2)
            cv2.putText(
                img,
                f"{confidence:.2f}",  
                (x, max(0, y - 10)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (0, 255, 0),
                2,
            )
    cv2.imwrite(out_path, img)
    print(f"  Saved annotated image: {out_path}")


def main():
    if not os.path.exists(MODEL_PATH):
        print(f"[FAIL] YuNet model not found at: {MODEL_PATH}")
        sys.exit(1)

    if not os.path.exists(INPUT_IMAGE):
        print(f"[FAIL] Input image not found: {INPUT_IMAGE}")
        sys.exit(1)

    original = cv2.imread(INPUT_IMAGE)
    if original is None:
        print(f"[FAIL] Could not decode image: {INPUT_IMAGE}")
        sys.exit(1)

    h, w = original.shape[:2]
    print(f"Loaded image: {INPUT_IMAGE} ({w}x{h})")

    angles = [0, 90, 180, 270]
    total_detections = 0

    for angle in angles:
        print(f"\n--- Rotation {angle}° ---")
        rotated = rotate_image(original, angle)
        rh, rw = rotated.shape[:2]

        # Create detector with current input size
        detector = cv2.FaceDetectorYN.create(
            model=MODEL_PATH,
            config="",
            input_size=(rw, rh),
            score_threshold=CONFIDENCE_THRESHOLD,
            nms_threshold=0.3
        )
        detector.setInputSize((rw, rh))

        faces = detect_faces(detector, rotated)

        if faces is None or faces.ndim != 2 or faces.shape[0] == 0:
            print("  No faces detected.")
            # Save unannotated image anyway (optional)
            out_path = f"image_boxed_{angle}.jpg"
            cv2.imwrite(out_path, rotated)
            print(f"  Saved (no boxes): {out_path}")
            continue

        count = faces.shape[0]
        total_detections += count
        print(f"  Detected {count} face(s):")
        for i in range(count):
            face = faces[i]
            x, y, fw, fh = int(face[0]), int(face[1]), int(face[2]), int(face[3])
            conf = float(face[4])
            print(f"    Face {i}: bbox=({x}, {y}, {fw}, {fh}) confidence={conf:.3f}")

        # Annotate and save
        out_path = f"image_boxed_{angle}.jpg"
        annotate_and_save(rotated, faces, out_path)

    print(f"\n--- Summary ---")
    print(f"Total faces detected across all rotations: {total_detections}")
    print("Check the saved images to visually verify detection quality.")


if __name__ == "__main__":
    main()