import cv2
import torch
import torch.nn.functional as F
from torchvision import models, transforms
import numpy as np
import os
import sys

# Ensure local FFmpeg is in PATH for ffmpeg-python
ffmpeg_bin_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ffmpeg_extracted", "ffmpeg-8.1.1-essentials_build", "bin")
if os.path.exists(ffmpeg_bin_dir):
    os.environ["PATH"] += os.pathsep + ffmpeg_bin_dir

import ffmpeg

def generate_mask(video_path, output_base_path):
    print(f"Generating mask with TorchVision for: {video_path}")
    
    # Load a higher precision segmentation model
    # ResNet50 provides MUCH sharper and higher-quality cutout edges than MobileNet for humans!
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = models.segmentation.deeplabv3_resnet50(weights='DeepLabV3_ResNet50_Weights.DEFAULT').to(device)
    model.eval()

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print("Error: Could not open video.")
        return None, None

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    # Optimization: Cap dimension to 640 for super fast CPU processing (4x-9x faster!)
    max_dim = 640
    if max(width, height) > max_dim:
        scale_f = max_dim / float(max(width, height))
        width = int(width * scale_f)
        height = int(height * scale_f)
        # Must be divisible by 2 for FFmpeg codecs
        width = (width // 2) * 2
        height = (height // 2) * 2
        print(f"Optimizing mask pipeline: Capping output to {width}x{height} for CPU efficiency.")

    fps = cap.get(cv2.CAP_PROP_FPS)
    
    bw_mask_mp4_path = output_base_path + "_bw_raw.mp4" # Use _raw to distinguish from optimized final H.264 mp4
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(bw_mask_mp4_path, fourcc, fps, (width, height), False)

    # Transform for the model
    # Set Resize(640) to match capped resolution exactly, ensuring 1:1 pixel sharp edges!
    preprocess = transforms.Compose([
        transforms.ToPILImage(),
        transforms.Resize(640), 
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])

    with torch.no_grad():
        while cap.isOpened():
            success, frame = cap.read()
            if not success:
                break

            # Convert BGR to RGB
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            input_tensor = preprocess(rgb_frame).unsqueeze(0).to(device)
            
            # Forward pass
            output = model(input_tensor)['out'][0]
            # Person class in COCO is 15
            mask = output.argmax(0) == 15
            
            # Resize mask back to original size
            mask_np = mask.byte().cpu().numpy() * 255
            mask_resized = cv2.resize(mask_np, (width, height), interpolation=cv2.INTER_LINEAR)
            
            # Gentle cleanup (3,3) kernel to avoid eroding details like fingers or hair!
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
            mask_resized = cv2.morphologyEx(mask_resized, cv2.MORPH_CLOSE, kernel)
            mask_resized = cv2.morphologyEx(mask_resized, cv2.MORPH_OPEN, kernel)
            
            # Smooth edges with slight blur for professional anti-aliased compositing
            mask_resized = cv2.GaussianBlur(mask_resized, (3, 3), 0)
            
            out.write(mask_resized)

    cap.release()
    out.release()
    
    webm_output = output_base_path + ".webm"
    mov_output = output_base_path + ".mov"
    bw_mp4_output = output_base_path + "_bw.mp4"

    # === 1. B&W mask as browser-friendly MP4 (H.264) for mobile canvas compositing ===
    print("Re-encoding B&W mask to optimized H.264 MP4 for Safari/Android...")
    bw_input = ffmpeg.input(bw_mask_mp4_path)
    out_bw_mp4 = ffmpeg.output(bw_input, bw_mp4_output, 
                                vcodec='libx264', 
                                pix_fmt='yuv420p',
                                preset='ultrafast',
                                **{'profile:v': 'baseline', 'level': '3.0', 'crf': '28'})
    ffmpeg.run(out_bw_mp4, overwrite_output=True, quiet=False)

    # === 2. Transparent WebM (VP9 alpha) for desktop browsers ===
    print("Merging mask with original video to create transparent WebM...")
    # Ensure main video input is scaled to EXACTLY match the mask resolution!
    video = ffmpeg.input(video_path).filter('scale', width, height)
    mask_stream = ffmpeg.input(bw_mask_mp4_path)
    subject = ffmpeg.filter([video, mask_stream], 'alphamerge')
    out_webm = ffmpeg.output(subject, webm_output, 
                             vcodec='libvpx-vp9', 
                             pix_fmt='yuva420p', 
                             deadline='realtime', # Speed up from 'good' to 'realtime'
                             **{
                                 'cpu-used': 8, # Boost CPU priority from 1 to 8
                                 'auto-alt-ref': 0, 
                                 'metadata:s:v:0': 'alpha_mode=1',
                                 'b:v': '1M', # Lower bitrate for speed
                                 'crf': '30'
                             })
    ffmpeg.run(out_webm, overwrite_output=True, quiet=False)

    # === 3. Transparent MOV (HEVC alpha) for Safari ===
    print("Merging mask with original video to create transparent MOV (HEVC)...")
    # Ensure main video input is scaled to match
    video_mov = ffmpeg.input(video_path).filter('scale', width, height)
    mask_stream_mov = ffmpeg.input(bw_mask_mp4_path)
    subject_mov = ffmpeg.filter([video_mov, mask_stream_mov], 'alphamerge')
    # Speed up compression preset from 'fast' to 'ultrafast'
    out_mov = ffmpeg.output(subject_mov, mov_output, vcodec='libx265', preset='ultrafast', pix_fmt='yuva420p', **{'x265-params': 'alpha=1', 'tag:v': 'hvc1'})
    ffmpeg.run(out_mov, overwrite_output=True, quiet=False)
    
    # Clean up intermediate mp4 (keep the webm version for serving)
    if os.path.exists(bw_mask_mp4_path):
        os.remove(bw_mask_mp4_path)
        
    print(f"Mask videos saved: {webm_output}, {mov_output}, {bw_mp4_output}")
    return webm_output, mov_output, bw_mp4_output

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python mask_generator.py <video_path> <output_base_path>")
    else:
        generate_mask(sys.argv[1], sys.argv[2])
