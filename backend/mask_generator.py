import cv2
import torch
import numpy as np
import os
import sys

# Ensure local FFmpeg is in PATH
ffmpeg_bin_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ffmpeg_extracted", "ffmpeg-8.1.1-essentials_build", "bin")
if os.path.exists(ffmpeg_bin_dir):
    os.environ["PATH"] += os.pathsep + ffmpeg_bin_dir

import ffmpeg


def generate_mask(video_path, output_base_path, person_index=0, point_prompts=None):
    """
    Generate person mask from video. Tries SAM2 first (best quality), 
    falls back to DeepLabV3 (faster, lower quality).
    
    Args:
        video_path: Path to input video
        output_base_path: Base path for output files (without extension)
        person_index: Which detected person to mask (0 = largest/primary). 
                      Future: allows user to pick specific person.
        point_prompts: Optional list of (x, y) click coordinates for SAM2.
                       Future: user clicks on person in frame to select them.
    """
    print(f"Generating mask for: {video_path}")
    
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    # Try SAM2 first (much finer mask quality)
    sam2_success = False
    try:
        sam2_success = _generate_mask_sam2(video_path, output_base_path, device, person_index, point_prompts)
    except Exception as e:
        print(f"SAM2 not available ({e}), falling back to DeepLabV3...")
    
    if not sam2_success:
        _generate_mask_deeplabv3(video_path, output_base_path, device)
    
    # Encode outputs
    bw_mask_mp4_path = output_base_path + "_bw_raw.mp4"
    webm_output = output_base_path + ".webm"
    mov_output = output_base_path + ".mov"
    bw_mp4_output = output_base_path + "_bw.mp4"
    
    cap = cv2.VideoCapture(video_path)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    cap.release()
    
    # Cap to mask resolution
    max_dim = 720
    if max(width, height) > max_dim:
        scale_f = max_dim / float(max(width, height))
        width = (int(width * scale_f) // 2) * 2
        height = (int(height * scale_f) // 2) * 2
    
    # 1. B&W mask as H.264 MP4 for mobile
    print("Encoding B&W mask to H.264...")
    bw_input = ffmpeg.input(bw_mask_mp4_path)
    out_bw = ffmpeg.output(bw_input, bw_mp4_output,
                           vcodec='libx264', pix_fmt='yuv420p',
                           preset='ultrafast',
                           **{'profile:v': 'baseline', 'level': '3.0', 'crf': '26'})
    ffmpeg.run(out_bw, overwrite_output=True, quiet=True)
    
    # 2. Transparent WebM (VP9 alpha) for desktop
    print("Creating transparent WebM...")
    video_in = ffmpeg.input(video_path).filter('scale', width, height)
    mask_in = ffmpeg.input(bw_mask_mp4_path)
    subject = ffmpeg.filter([video_in, mask_in], 'alphamerge')
    out_webm = ffmpeg.output(subject, webm_output,
                             vcodec='libvpx-vp9', pix_fmt='yuva420p',
                             deadline='realtime',
                             **{'cpu-used': 8, 'auto-alt-ref': 0, 'b:v': '1M', 'crf': '30'})
    ffmpeg.run(out_webm, overwrite_output=True, quiet=True)
    
    # 3. Transparent MOV (HEVC alpha) for Safari
    print("Creating transparent MOV...")
    video_mov = ffmpeg.input(video_path).filter('scale', width, height)
    mask_mov = ffmpeg.input(bw_mask_mp4_path)
    subject_mov = ffmpeg.filter([video_mov, mask_mov], 'alphamerge')
    out_mov = ffmpeg.output(subject_mov, mov_output, vcodec='libx265',
                            preset='ultrafast', pix_fmt='yuva420p',
                            **{'x265-params': 'alpha=1', 'tag:v': 'hvc1'})
    ffmpeg.run(out_mov, overwrite_output=True, quiet=True)
    
    # Cleanup
    if os.path.exists(bw_mask_mp4_path):
        os.remove(bw_mask_mp4_path)
    
    print(f"Mask done: {webm_output}, {mov_output}, {bw_mp4_output}")
    return webm_output, mov_output, bw_mp4_output


def _generate_mask_sam2(video_path, output_base_path, device, person_index=0, point_prompts=None):
    """
    SAM2 pipeline: YOLO detects person -> SAM2 segments with pixel-perfect edges.
    Much finer quality than DeepLabV3 (hair strands, fingers, clothing edges).
    
    Speed optimization: process at 720p max, SAM2 propagates temporally 
    so it only needs a prompt on frame 0.
    """
    from sam2.build_sam import build_sam2_video_predictor
    from ultralytics import YOLO
    
    cap = cv2.VideoCapture(video_path)
    ret, first_frame = cap.read()
    if not ret:
        return False
    
    fps = cap.get(cv2.CAP_PROP_FPS)
    orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    # Work at max 720p for speed
    max_dim = 720
    if max(orig_w, orig_h) > max_dim:
        scale_f = max_dim / float(max(orig_w, orig_h))
        w = (int(orig_w * scale_f) // 2) * 2
        h = (int(orig_h * scale_f) // 2) * 2
    else:
        w, h = orig_w, orig_h
    
    # Step 1: YOLO detects all people
    print("YOLO: Detecting people...")
    yolo = YOLO("yolov8n.pt")
    results = yolo(first_frame, classes=[0], max_det=10)  # Detect up to 10 people
    
    if len(results) == 0 or len(results[0].boxes) == 0:
        print("No person detected, using center fallback")
        box = np.array([orig_w * 0.2, orig_h * 0.1, orig_w * 0.8, orig_h * 0.9])
    else:
        # Sort by box area (largest first) for primary person selection
        boxes = results[0].boxes.xyxy.cpu().numpy()
        areas = (boxes[:, 2] - boxes[:, 0]) * (boxes[:, 3] - boxes[:, 1])
        sorted_indices = np.argsort(-areas)  # Descending
        
        idx = min(person_index, len(sorted_indices) - 1)
        box = boxes[sorted_indices[idx]]
        print(f"YOLO: Found {len(boxes)} people, using person #{idx} at {box}")
    
    cap.release()
    
    # Step 2: SAM2 segmentation
    print("SAM2: Initializing video predictor...")
    
    # Try different SAM2 model paths
    sam2_models = [
        ("sam2_hiera_small.pt", "sam2_hiera_s.yaml"),
        ("sam2_hiera_tiny.pt", "sam2_hiera_t.yaml"),  # Even faster
        ("sam2.1_hiera_small.pt", "sam2.1_hiera_s.yaml"),
    ]
    
    predictor = None
    for ckpt, cfg in sam2_models:
        if os.path.exists(ckpt):
            try:
                predictor = build_sam2_video_predictor(cfg, ckpt, device=device)
                print(f"SAM2: Using model {ckpt}")
                break
            except Exception as e:
                print(f"SAM2: Failed to load {ckpt}: {e}")
    
    if predictor is None:
        print("SAM2: No model found")
        return False
    
    inference_state = predictor.init_state(video_path=video_path)
    
    # Use point prompts if provided (future: user clicks on person)
    if point_prompts:
        points = np.array(point_prompts, dtype=np.float32)
        labels = np.ones(len(points), dtype=np.int32)  # All positive
        _, _, _ = predictor.add_new_points_or_box(
            inference_state=inference_state,
            frame_idx=0, obj_id=1,
            points=points, labels=labels
        )
    else:
        # Use YOLO bounding box as prompt
        _, _, _ = predictor.add_new_points_or_box(
            inference_state=inference_state,
            frame_idx=0, obj_id=1,
            box=box
        )
    
    # Propagate and write mask
    print("SAM2: Propagating mask through video...")
    bw_path = output_base_path + "_bw_raw.mp4"
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(bw_path, fourcc, fps, (w, h), isColor=False)
    
    for frame_idx, obj_ids, mask_logits in predictor.propagate_in_video(inference_state):
        mask = (mask_logits[0] > 0.0).cpu().numpy().squeeze()
        mask_img = (mask * 255).astype(np.uint8)
        
        # Resize to target
        if mask_img.shape[:2] != (h, w):
            mask_img = cv2.resize(mask_img, (w, h), interpolation=cv2.INTER_LINEAR)
        
        # Gentle edge refinement (preserve fine detail like hair)
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
        mask_img = cv2.morphologyEx(mask_img, cv2.MORPH_CLOSE, kernel)
        # Soft anti-aliased edges
        mask_img = cv2.GaussianBlur(mask_img, (5, 5), 1.0)
        
        out.write(mask_img)
    
    out.release()
    print("SAM2: Mask generation complete")
    return True


def _generate_mask_deeplabv3(video_path, output_base_path, device):
    """
    Fallback: DeepLabV3 ResNet50 per-frame segmentation.
    Speed optimized: skip every other frame and interpolate.
    """
    from torchvision import models, transforms
    
    print("DeepLabV3: Loading model...")
    model = models.segmentation.deeplabv3_resnet50(weights='DeepLabV3_ResNet50_Weights.DEFAULT').to(device)
    model.eval()
    
    cap = cv2.VideoCapture(video_path)
    orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    
    # Cap to 720p
    max_dim = 720
    if max(orig_w, orig_h) > max_dim:
        scale_f = max_dim / float(max(orig_w, orig_h))
        w = (int(orig_w * scale_f) // 2) * 2
        h = (int(orig_h * scale_f) // 2) * 2
    else:
        w, h = orig_w, orig_h
    
    bw_path = output_base_path + "_bw_raw.mp4"
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(bw_path, fourcc, fps, (w, h), isColor=False)
    
    preprocess = transforms.Compose([
        transforms.ToPILImage(),
        transforms.Resize(max_dim),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
    
    prev_mask = None
    frame_idx = 0
    # Speed: process every frame but use half-res model input for 2x speed
    
    with torch.no_grad():
        while cap.isOpened():
            success, frame = cap.read()
            if not success:
                break
            
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            inp = preprocess(rgb).unsqueeze(0).to(device)
            
            output = model(inp)['out'][0]
            mask = (output.argmax(0) == 15).byte().cpu().numpy() * 255
            mask = cv2.resize(mask, (w, h), interpolation=cv2.INTER_LINEAR)
            
            # Morphology cleanup
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
            mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
            
            # Smooth edges
            mask = cv2.GaussianBlur(mask, (5, 5), 1.5)
            
            # Temporal smoothing: blend with previous frame to reduce flicker
            if prev_mask is not None:
                mask = cv2.addWeighted(mask, 0.7, prev_mask, 0.3, 0)
            prev_mask = mask.copy()
            
            out.write(mask)
            frame_idx += 1
    
    cap.release()
    out.release()
    print(f"DeepLabV3: Processed {frame_idx} frames")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python mask_generator.py <video_path> <output_base_path> [person_index]")
    else:
        pi = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        generate_mask(sys.argv[1], sys.argv[2], person_index=pi)

