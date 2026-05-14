import os
import json
import asyncio
import subprocess
import uuid
from playwright.async_api import async_playwright

async def render_text_to_video(json_path: str, output_video_path: str, fps: int = 30, layer_type: str = 'all'):
    """
    Reads output_captions.json, uses Playwright to render frames, 
    and stitches them into a transparent video via FFmpeg.
    layer_type: 'all', 'behind', 'front'
    """
    print(f"Starting Playwright headless renderer for {json_path} (Layer: {layer_type})...")
    
    with open(json_path, 'r', encoding='utf-8') as f:
        project_data = json.load(f)
        
    width = project_data.get('resolution', {}).get('width', 1080)
    height = project_data.get('resolution', {}).get('height', 1920)
    
    # Calculate max duration
    max_time = 0
    for c in project_data.get('captions', []):
        if c.get('end_time', 0) > max_time:
            max_time = c.get('end_time', 0)
            
    # Add a little padding
    duration = max_time + 0.5
    total_frames = int(duration * fps)
    
    # Create temp directory for frames (use unique name for parallel rendering)
    unique_id = uuid.uuid4().hex[:8]
    tmp_dir = os.path.join(os.path.dirname(output_video_path), f"tmp_frames_{layer_type}_{unique_id}")
    os.makedirs(tmp_dir, exist_ok=True)
    
    template_path = os.path.join(os.path.dirname(__file__), "render_template.html")
    # Replace backslashes for file:// URI on Windows
    template_path = template_path.replace("\\", "/")
    file_url = f"file:///{template_path}"
    
    print(f"Launching Chrome to render {total_frames} frames at {width}x{height}...")
    
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        # Transparent background is crucial
        context = await browser.new_context(
            viewport={'width': width, 'height': height},
        )
        page = await context.new_page()
        
        await page.goto(file_url)
        
        # Load JSON data into the page and set layer filter
        await page.evaluate(f"window.loadProject({json.dumps(project_data)})")
        await page.evaluate(f"window.setLayerFilter('{layer_type}')")
        
        for frame_index in range(total_frames):
            current_time = frame_index / fps
            
            # Seek the HTML timeline
            await page.evaluate(f"window.seekTo({current_time})")
            
            # Wait a tiny bit for fonts to load and CSS to apply on first frame
            if frame_index == 0:
                await page.wait_for_timeout(1000)
                
            frame_path = os.path.join(tmp_dir, f"frame_{frame_index:05d}.png")
            # omit_background=True forces the Chrome background to be transparent
            await page.screenshot(path=frame_path, omit_background=True)
            
            if frame_index % 30 == 0:
                print(f"Rendered frame {frame_index}/{total_frames}")

        await browser.close()
        
    # Stitch frames using FFmpeg
    print("Stitching frames into transparent video using FFmpeg...")
    
    # -c:v qtrle preserves the alpha channel (lossless animation codec)
    ffmpeg_cmd = [
        "ffmpeg", "-y",
        "-framerate", str(fps),
        "-i", os.path.join(tmp_dir, "frame_%05d.png"),
        "-c:v", "qtrle", 
        output_video_path
    ]
    
    try:
        subprocess.run(ffmpeg_cmd, check=True)
        print(f"✅ Text video saved successfully to {output_video_path}")
    except subprocess.CalledProcessError as e:
        print(f"❌ FFmpeg stitching failed: {e}")
        return None
    
    # Cleanup frames
    for file in os.listdir(tmp_dir):
        os.remove(os.path.join(tmp_dir, file))
    os.rmdir(tmp_dir)
    
    return output_video_path

if __name__ == "__main__":
    # Test script if executed directly
    # Requires an output_captions.json in the project root
    import sys
    
    project_root = os.path.dirname(os.path.dirname(__file__))
    json_path = os.path.join(project_root, "output_captions.json")
    out_video = os.path.join(project_root, "test_text_video.mov")
    
    if os.path.exists(json_path):
        asyncio.run(render_text_to_video(json_path, out_video))
    else:
        print("Test JSON not found.")
