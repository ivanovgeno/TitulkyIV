from fastapi import FastAPI, UploadFile, File, BackgroundTasks
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
import os
import shutil
import uuid
from mvp_transcriber import process_video

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="IvCaptions Backend API")

# Allow CORS for frontend (e.g. Vercel)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = "uploads"
OUTPUT_DIR = "outputs"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

app.mount("/outputs", StaticFiles(directory=OUTPUT_DIR), name="outputs")

@app.post("/api/v1/process/transcribe")
async def transcribe_video(background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    """
    Receives a video file, saves it, and schedules the Whisper transcription.
    """
    project_id = str(uuid.uuid4())
    video_path = os.path.join(UPLOAD_DIR, f"{project_id}_{file.filename}")
    output_json_path = os.path.join(OUTPUT_DIR, f"{project_id}_captions.json")
    
    # Save uploaded file
    with open(video_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Schedule processing
    background_tasks.add_task(process_video, video_path, output_json_path)
    
    return JSONResponse({
        "status": "processing",
        "project_id": project_id,
        "message": "Video uploaded successfully. Transcription started in background."
    })

@app.get("/api/v1/process/result/{project_id}")
async def get_result(project_id: str):
    """
    Checks if the output JSON exists and returns it.
    """
    for filename in os.listdir(OUTPUT_DIR):
        if filename.startswith(project_id):
            if filename.endswith(".json"):
                output_json_path = os.path.join(OUTPUT_DIR, filename)
                with open(output_json_path, "r", encoding="utf-8") as f:
                    import json
                    data = json.load(f)
                return JSONResponse({"status": "completed", "data": data})
            elif filename.endswith(".error"):
                error_path = os.path.join(OUTPUT_DIR, filename)
                with open(error_path, "r", encoding="utf-8") as f:
                    err_msg = f.read()
                return JSONResponse({"status": "error", "message": err_msg})
            
    return JSONResponse({"status": "processing_or_not_found"})

@app.post("/api/v1/render/full_project")
async def render_full_project(
    background_tasks: BackgroundTasks,
    project_id: str,
    video_path: str,
    json_path: str,
    mask_path: str = None
):
    """
    High-level endpoint:
    1. Renders behind-captions (if mask exists)
    2. Renders front-captions
    3. Composites final video
    """
    background_tasks.add_task(
        orchestrate_render, 
        project_id, 
        video_path, 
        json_path, 
        mask_path
    )
    return JSONResponse({
        "status": "started",
        "message": "Full project rendering started in background."
    })

async def orchestrate_render(project_id, video_path, json_path, mask_path):
    from text_renderer import render_text_to_video
    from compositor import render_final_video
    
    output_final = os.path.join(OUTPUT_DIR, f"{project_id}_final.mp4")
    
    if mask_path and os.path.exists(mask_path):
        # Multi-layer path
        behind_video = os.path.join(OUTPUT_DIR, f"{project_id}_text_behind.mov")
        front_video = os.path.join(OUTPUT_DIR, f"{project_id}_text_front.mov")
        
        # Render layers (async Playwright calls)
        await render_text_to_video(json_path, behind_video, layer_type='behind')
        await render_text_to_video(json_path, front_video, layer_type='front')
        
        # Composite
        render_final_video(
            original_video_path=video_path,
            output_path=output_final,
            behind_text_video_path=behind_video,
            front_text_video_path=front_video,
            mask_video_path=mask_path
        )
    else:
        # Single-layer path
        all_text_video = os.path.join(OUTPUT_DIR, f"{project_id}_text_all.mov")
        await render_text_to_video(json_path, all_text_video, layer_type='all')
        
        render_final_video(
            original_video_path=video_path,
            output_path=output_final,
            text_video_path=all_text_video
        )
    
    print(f"Project {project_id} fully rendered: {output_final}")

def process_mask(project_id: str, video_path: str, output_base_path: str):
    from mask_generator import generate_mask
    try:
        generate_mask(
            video_path=video_path,
            output_base_path=output_base_path
        )
        with open(f"{output_base_path}.done", "w") as f:
            f.write("done")
    except Exception as e:
        print(f"Mask generation error: {e}")
        with open(f"{output_base_path}.error", "w") as f:
            f.write(str(e))

@app.post("/api/v1/generate-mask")
async def generate_mask(background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    """
    Triggers Torchvision MobileNetV3 segmentation to generate a person mask video asynchronously.
    """
    project_id = str(uuid.uuid4())
    video_path = os.path.join(UPLOAD_DIR, f"{project_id}_maskinput_{file.filename}")
    output_base_filename = f"{project_id}_mask"
    output_base_path = os.path.join(OUTPUT_DIR, output_base_filename)
    
    with open(video_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    background_tasks.add_task(process_mask, project_id, video_path, output_base_path)
    
    return JSONResponse({
        "status": "processing",
        "project_id": project_id,
        "message": "Mask generation started in background."
    })

@app.get("/api/v1/generate-mask/status/{project_id}")
async def get_mask_status(project_id: str):
    output_base_filename = f"{project_id}_mask"
    output_base_path = os.path.join(OUTPUT_DIR, output_base_filename)
    
    if os.path.exists(f"{output_base_path}.done"):
        # For local dev/cloud, we return relative URL from the mount point
        return JSONResponse({
            "status": "completed", 
            "mask_url_webm": f"/outputs/{output_base_filename}.webm",
            "mask_url_mov": f"/outputs/{output_base_filename}.mov",
            "mask_url_bw": f"/outputs/{output_base_filename}_bw.mp4"
        })
    elif os.path.exists(f"{output_base_path}.error"):
        with open(f"{output_base_path}.error", "r") as f:
            err = f.read()
        return JSONResponse({"status": "error", "message": err})
    else:
        return JSONResponse({"status": "processing"})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
