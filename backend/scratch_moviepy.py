from moviepy import VideoFileClip
import os

target = r"c:\Projekty\IvCaptions\backend\outputs\7415e580-8126-48d0-bc61-13166725639f_mask.webm"
try:
    clip = VideoFileClip(target, has_mask=True)
    print(f"Clip size: {clip.size}")
    print(f"Has mask (alpha): {clip.mask is not None}")
    if clip.mask:
        # Sample a frame and check if it has non-zero alpha values
        frame = clip.mask.get_frame(1.0)
        import numpy as np
        print(f"Alpha sample shape: {frame.shape}")
        print(f"Max alpha: {np.max(frame)}, Min alpha: {np.min(frame)}")
    clip.close()
except Exception as e:
    print(f"Error loading clip: {e}")
