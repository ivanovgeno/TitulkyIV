import subprocess
import sys
import os

target = r"c:\Projekty\IvCaptions\backend\outputs\7415e580-8126-48d0-bc61-13166725639f_mask.webm"
if not os.path.exists(target):
    print(f"File not found: {target}")
    sys.exit(1)

try:
    # Use whatever ffmpeg command python-ffmpeg was able to find
    res = subprocess.run(["ffmpeg", "-i", target], stderr=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    print(res.stderr)
except Exception as e:
    print(f"FFmpeg not running directly: {e}")
