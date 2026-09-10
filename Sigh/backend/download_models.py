#!/usr/bin/env python
"""
Download YuNet and SFace models from OpenCV Zoo.

Run this script before starting the server:
    python download_models.py

This will download:
1. YuNet face detector (face_detection_yunet_2023mar.onnx)
2. SFace face recognizer (face_recognition_sface_2021dec.onnx) - similar to MobileFaceNet

Total size: ~25 MB

Note: Models are stored with Git LFS on GitHub. Direct raw URLs don't work.
We use Hugging Face mirror which has the actual files.
"""

import os
import urllib.request
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Models should be downloaded to the test1_yunet app directory
# (where face_streamer.py looks for them)
BASE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'test1_yunet')


def download_model(url, filename, description):
    """Download a model from URL."""
    filepath = os.path.join(BASE_DIR, filename)

    if os.path.exists(filepath) and os.path.getsize(filepath) > 10000:
        logger.info(f"✓ {description} already exists: {filename}")
        return filepath

    # Remove LFS pointer files if they exist
    if os.path.exists(filepath) and os.path.getsize(filepath) < 10000:
        logger.info(f"Removing Git LFS pointer file: {filepath}")
        os.remove(filepath)

    logger.info(f"Downloading {description}...")
    try:
        urllib.request.urlretrieve(url, filepath)
        size_mb = os.path.getsize(filepath) / (1024 * 1024)
        logger.info(f"✓ Downloaded {description}: {filename} ({size_mb:.1f} MB)")
        return filepath
    except Exception as e:
        logger.error(f"Failed to download {description}: {e}")
        raise


def main():
    """Download all required models."""
    print("=" * 60)
    print("YuNet + SFace Model Downloader")
    print("=" * 60)
    print()

    # YuNet face detector - download from OpenCV Zoo using alternative method
    yunet_url = (
        "https://github.com/opencv/opencv_zoo/raw/refs/heads/main/models/"
        "face_detection_yunet/face_detection_yunet_2023mar.onnx"
    )
    download_model(
        yunet_url,
        "face_detection_yunet_2023mar.onnx",
        "YuNet face detector"
    )

    print()

    # SFace face recognizer - download from Hugging Face (more reliable)
    sface_url = (
        "https://huggingface.co/opencv/face_recognition_sface/"
        "resolve/main/face_recognition_sface_2021dec.onnx"
    )
    download_model(
        sface_url,
        "face_recognition_sface_2021dec.onnx",
        "SFace face recognizer"
    )

    print()
    print("=" * 60)
    print("All models downloaded successfully!")
    print("=" * 60)
    print()
    print("Usage:")
    print("  1. Install requirements: pip install -r requirements.txt")
    print("  2. Run migrations: python manage.py migrate")
    print("  3. Start server: python manage.py runserver")
    print()


if __name__ == "__main__":
    main()
