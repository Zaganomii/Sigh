#!/usr/bin/env python
"""
test.py - Compare two static images using the same YuNet + SFace pipeline
that face_streamer.py uses in production.

Usage:
    python test.py img_a.jpg img_b.jpg
    python test.py img_a.jpg img_b.jpg --debug
    python test.py img_a.jpg img_b.jpg --save-crops out_dir/

Setup (Django):
    The script bootstraps Django so that any `from django.conf import settings`
    lookups inside face_streamer.py (model paths, thresholds) work correctly.

    If your project uses a non-default settings module, override it:
        DJANGO_SETTINGS_MODULE=myproj.settings python test.py a.jpg b.jpg
    or pass --settings myproj.settings

Output:
    - Detected face bbox + detector confidence for each image
    - Landmark positions (if --debug)
    - Cosine similarity between the two embeddings
    - PASS / FAIL against the configured threshold

Note:
    This script deliberately imports YuNetFaceDetector and SFaceRecognizer
    from face_streamer so there is exactly one code path being tested. If
    you fix a bug in face_streamer, this script picks it up automatically.
"""

import argparse
import os
import sys


# ---------------------------------------------------------------------------
# Django bootstrap (must happen BEFORE importing face_streamer, which reads
# settings at class-init time).
# ---------------------------------------------------------------------------
def _bootstrap_django(settings_module):
    if not settings_module:
        settings_module = os.environ.get("DJANGO_SETTINGS_MODULE")
    if not settings_module:
        # Try a couple of common conventions so casual usage doesn't need env vars.
        for candidate in ("settings", "config.settings", "myproject.settings"):
            try:
                __import__(candidate)
                settings_module = candidate
                break
            except Exception:
                continue
    if not settings_module:
        sys.exit(
            "Could not locate Django settings. Set DJANGO_SETTINGS_MODULE "
            "or pass --settings."
        )
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", settings_module)
    try:
        import django
        django.setup()
    except Exception as e:
        sys.exit(f"Django setup failed: {e}")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def load_image(path):
    import cv2
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    img = cv2.imread(path, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError(f"cv2.imread returned None for {path} (not a valid image?)")
    return img


def pick_best_face(faces):
    """Largest-area face wins; ties broken by detector confidence."""
    def key(f):
        x, y, w, h = f["bbox"]
        return (w * h, f["confidence"])
    return max(faces, key=key)


def describe_detection(label, img, face):
    h, w = img.shape[:2]
    x, y, bw, bh = face["bbox"]
    conf = face["confidence"]
    area_pct = 100.0 * (bw * bh) / max(1, w * h)
    print(f"[{label}] image        : {w}x{h}")
    print(f"[{label}] bbox         : x={x} y={y} w={bw} h={bh}")
    print(f"[{label}] det conf     : {conf:.4f}")
    print(f"[{label}] face area    : {area_pct:.2f}% of frame")
    lm = face.get("landmarks")
    if lm is not None and len(lm) == 10:
        # YuNet order: right_eye, left_eye, nose, right_mouth, left_mouth
        pts = lm.reshape(5, 2)
        names = ["right_eye", "left_eye", "nose", "right_mouth", "left_mouth"]
        print(f"[{label}] landmarks    :")
        for n, (px, py) in zip(names, pts):
            print(f"[{label}]   {n:12s} ({px:7.1f}, {py:7.1f})")
    else:
        print(f"[{label}] landmarks    : NONE")


def save_crops(out_dir, label, img, face):
    """Save the aligned 112x112 crop and the raw bbox crop for visual inspection."""
    import cv2
    from test1_yunet.face_streamer import SFaceRecognizer

    os.makedirs(out_dir, exist_ok=True)

    x, y, w, h = face["bbox"]
    lm = face.get("landmarks")

    # Raw bbox crop (for sanity-checking the detector)
    H, W = img.shape[:2]
    x1, y1 = max(0, x), max(0, y)
    x2, y2 = min(W, x + w), min(H, y + h)
    bbox_crop = img[y1:y2, x1:x2]
    if bbox_crop.size > 0:
        cv2.imwrite(os.path.join(out_dir, f"{label}_bbox.jpg"), bbox_crop)

    # Aligned 112x112 crop (what SFace actually sees)
    if lm is not None and len(lm) == 10:
        aligned = SFaceRecognizer._align_face(img, lm)
        if aligned is not None:
            cv2.imwrite(os.path.join(out_dir, f"{label}_aligned.jpg"), aligned)
        else:
            print(f"[{label}] WARNING: alignment returned None")
    else:
        print(f"[{label}] WARNING: no landmarks -> cannot produce aligned crop")

    # Annotated full frame (dots + box) — mirrors what the live UI draws
    annotated = img.copy()
    color = (0, 0, 255)
    cv2.rectangle(annotated, (x, y), (x + w, y + h), color, 2)
    if lm is not None and len(lm) == 10:
        for i in range(0, 10, 2):
            cv2.circle(annotated, (int(lm[i]), int(lm[i + 1])), 3,
                       (0, 255, 255), -1)
    cv2.imwrite(os.path.join(out_dir, f"{label}_annotated.jpg"), annotated)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="Compare two images with YuNet + SFace.")
    ap.add_argument("image_a", help="path to first image")
    ap.add_argument("image_b", help="path to second image")
    ap.add_argument("--settings", default=None,
                    help="Django settings module (else uses DJANGO_SETTINGS_MODULE)")
    ap.add_argument("--threshold", type=float, default=None,
                    help="override similarity threshold (else uses settings)")
    ap.add_argument("--debug", action="store_true",
                    help="print landmarks and per-image stats")
    ap.add_argument("--save-crops", default=None,
                    help="directory to write aligned/bbox/annotated crops into")
    ap.add_argument("--rotate-portrait", action="store_true",
                    help="rotate portrait images 90° CW before detection "
                         "(use for phone-taken photos with EXIF stripped)")
    args = ap.parse_args()

    _bootstrap_django(args.settings)

    # Import AFTER django.setup() so settings are available.
    import cv2
    import numpy as np
    from test1_yunet.face_streamer import YuNetFaceDetector, SFaceRecognizer

    # --- instantiate the same pipeline used at runtime -------------------
    det = YuNetFaceDetector()
    rec = SFaceRecognizer()

    print("=" * 70)
    print(f"YuNet model : {det.model_path}")
    print(f"SFace model : {rec.model_path}")
    print("=" * 70)

    # --- load + optionally rotate ----------------------------------------
    img_a = load_image(args.image_a)
    img_b = load_image(args.image_b)

    if args.rotate_portrait:
        for name, im in (("a", img_a), ("b", img_b)):
            h, w = im.shape[:2]
            if h > w * 1.1:
                if name == "a":
                    img_a = cv2.rotate(im, cv2.ROTATE_90_CLOCKWISE)
                else:
                    img_b = cv2.rotate(im, cv2.ROTATE_90_CLOCKWISE)

    # --- detect -----------------------------------------------------------
    faces_a = det.detect_faces(img_a)
    faces_b = det.detect_faces(img_b)

    if not faces_a:
        sys.exit(f"FAIL: no face detected in {args.image_a}")
    if not faces_b:
        sys.exit(f"FAIL: no face detected in {args.image_b}")

    face_a = pick_best_face(faces_a)
    face_b = pick_best_face(faces_b)

    print(f"\nDetected {len(faces_a)} face(s) in A, {len(faces_b)} face(s) in B.")
    print("Using the largest face in each image.\n")

    if args.debug:
        describe_detection("A", img_a, face_a)
        print()
        describe_detection("B", img_b, face_b)
        print()

    # --- embed ------------------------------------------------------------
    x, y, w, h = face_a["bbox"]
    emb_a = rec.extract_embedding(img_a, (x, y, w, h), face_a.get("landmarks"))
    x, y, w, h = face_b["bbox"]
    emb_b = rec.extract_embedding(img_b, (x, y, w, h), face_b.get("landmarks"))

    if emb_a is None:
        sys.exit("FAIL: embedding A is None (alignment/quality gate rejected it)")
    if emb_b is None:
        sys.exit("FAIL: embedding B is None (alignment/quality gate rejected it)")

    if args.debug:
        for tag, e in (("A", emb_a), ("B", emb_b)):
            print(f"[{tag}] embedding: dim={e.shape} norm={np.linalg.norm(e):.4f} "
                  f"std={e.std():.4f} min={e.min():.4f} max={e.max():.4f}")
        print()

    # --- compare ----------------------------------------------------------
    similarity = rec.compute_similarity(emb_a, emb_b)

    # Resolve threshold the same way verify_face does, with the single-entry
    # floor applied when only one side is being compared (which is our case).
    threshold = args.threshold
    if threshold is None:
        try:
            from django.conf import settings
            threshold = getattr(settings, "FACE_SIMILARITY_THRESHOLD", 0.65)
        except Exception:
            threshold = 0.65
    single_floor = max(threshold, 0.75)

    print("-" * 70)
    print(f"Cosine similarity   : {similarity:.4f}")
    print(f"Configured threshold: {threshold:.4f}")
    print(f"Single-pair floor   : {single_floor:.4f}  (max(threshold, 0.75))")
    print("-" * 70)

    if similarity >= single_floor:
        verdict = "MATCH  (same person, above single-pair floor)"
    elif similarity >= threshold:
        verdict = "AMBIGUOUS  (above base threshold but below single-pair floor)"
    else:
        verdict = "NO MATCH  (below threshold)"

    print(f"Verdict             : {verdict}")
    print("=" * 70)

    # --- optional crops ---------------------------------------------------
    if args.save_crops:
        save_crops(args.save_crops, "a", img_a, face_a)
        save_crops(args.save_crops, "b", img_b, face_b)
        print(f"\nSaved crops to {os.path.abspath(args.save_crops)}")
        print("  *_aligned.jpg   -> the 112x112 image SFace actually embedded")
        print("  *_bbox.jpg      -> the raw detector bounding box crop")
        print("  *_annotated.jpg -> full frame with box + landmark dots")
        print("Compare the two *_aligned.jpg files side by side: they should")
        print("both look like clean, roughly frontal faces with eyes on the")
        print("same horizontal line. If either is black, squashed, or upside")
        print("down, the alignment step is the problem.")


if __name__ == "__main__":
    main()