import os
import sys

# Ensure local FFmpeg is in PATH for ffmpeg-python
ffmpeg_bin_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ffmpeg_extracted", "ffmpeg-8.1.1-essentials_build", "bin")
if os.path.exists(ffmpeg_bin_dir):
    os.environ["PATH"] += os.pathsep + ffmpeg_bin_dir

import ffmpeg

def render_final_video(
    original_video_path: str,
    output_path: str,
    text_video_path: str = None, # Fallback for single layer
    behind_text_video_path: str = None,
    front_text_video_path: str = None,
    mask_video_path: str = None
):
    """
    Composites the final video with multi-layer text support.
    Logic:
    1. Base Video
    2. Overlay 'Behind' captions
    3. Overlay 'Subject' (extracted via Mask)
    4. Overlay 'Front' captions
    """
    print(f"Starting multi-layer compositing for {output_path}...")
    
    # Inputs
    video = ffmpeg.input(original_video_path)
    
    current_stream = video

    # 1. Handle Behind Layer
    if behind_text_video_path and os.path.exists(behind_text_video_path):
        print("Overlaying 'behind' captions...")
        behind_text = ffmpeg.input(behind_text_video_path)
        current_stream = ffmpeg.overlay(current_stream, behind_text, x=0, y=0)
    elif text_video_path and os.path.exists(text_video_path) and not front_text_video_path:
        # Fallback if only one text video provided and no front layer specified
        print("Overlaying single-layer captions behind subject (fallback)...")
        text = ffmpeg.input(text_video_path)
        current_stream = ffmpeg.overlay(current_stream, text, x=0, y=0)

    # 2. Handle Subject Layer (The Masking Magic)
    if mask_video_path and os.path.exists(mask_video_path):
        print("Mask found. Overlaying extracted subject layer...")
        subject = ffmpeg.input(mask_video_path)
        # Overlay Subject on top of current stream (which has 'behind' captions)
        current_stream = ffmpeg.overlay(current_stream, subject, x=0, y=0)

    # 3. Handle Front Layer
    if front_text_video_path and os.path.exists(front_text_video_path):
        print("Overlaying 'front' captions...")
        front_text = ffmpeg.input(front_text_video_path)
        current_stream = ffmpeg.overlay(current_stream, front_text, x=0, y=0)
    
    final_video = current_stream

    # We want to keep the original audio
    audio = video.audio

    # Output parameters
    out = ffmpeg.output(
        final_video, 
        audio, 
        output_path,
        vcodec='libx264',
        acodec='aac',
        preset='fast',
        crf=23
    )
    
    # Run the filtergraph
    ffmpeg.run(out, overwrite_output=True, quiet=False)
    print(f"Compositing completed. Saved to {output_path}")
    return output_path

if __name__ == "__main__":
    # Test stub (requires actual files to run)
    pass
