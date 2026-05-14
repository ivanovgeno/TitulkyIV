import urllib.request
import zipfile
import os

url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
zip_path = "ffmpeg.zip"
print("Downloading FFmpeg...")
urllib.request.urlretrieve(url, zip_path)
print("Extracting FFmpeg...")
with zipfile.ZipFile(zip_path, 'r') as zip_ref:
    for member in zip_ref.namelist():
        if member.endswith("ffmpeg.exe"):
            member_source = zip_ref.open(member)
            target_path = os.path.join(os.getcwd(), "ffmpeg.exe")
            with open(target_path, "wb") as f:
                f.write(member_source.read())
            break
os.remove(zip_path)
print("FFmpeg setup complete.")
