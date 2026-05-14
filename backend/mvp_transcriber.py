import os
import json
import subprocess
import whisper 
import tempfile

def extract_audio(video_path: str, audio_path: str):
    """Extracts 16kHz WAV audio using FFmpeg for Whisper."""
    # Auto-detect platform to use correct FFmpeg binary
    import sys
    ffmpeg_path = "ffmpeg" # Standard system path for Linux/Docker
    
    if sys.platform == "win32":
        local_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ffmpeg_extracted", "ffmpeg-8.1.1-essentials_build", "bin", "ffmpeg.exe")
        if os.path.exists(local_path):
            ffmpeg_path = local_path

    command = [
        ffmpeg_path, "-y", "-i", video_path,
        "-vn", "-acodec", "pcm_s16le", "-ar", "16000", "-ac", "1",
        audio_path
    ]
    subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

def generate_base_json(transcription_result, video_width=1080, video_height=1920):
    """Converts Whisper word-level output to the IvCaptions base schema."""
    captions = []
    
    # Whisper word-level timestamps are in result['segments'][i]['words']
    word_index = 0
    for segment in transcription_result.get("segments", []):
        for word_data in segment.get("words", []):
            word_text = word_data["word"].strip()
            
            caption_obj = {
                "id": f"word_{word_index:04d}",
                "text": word_text,
                "start_time": round(word_data["start"], 3),
                "end_time": round(word_data["end"], 3),
                "category": "Main", # Default category
                "style": {
                    "font_family": "Inter",
                    "font_weight": "900",
                    "font_size": 90,
                    "color": {
                        "type": "gradient", 
                        "colors": ["#FFD700", "#D4AF37", "#AA771C"] 
                    },
                    "stroke": {"width": 6, "color": "#000000"},
                    "shadow": {"color": "rgba(0, 0, 0, 0.9)", "blur": 20, "offset_x": 0, "offset_y": 8},
                    "glow": {"intensity": 0.4, "color": "#D4AF37"}
                },
                "transform_3d": {
                    "position": {"x": video_width // 2, "y": video_height // 2, "z": 0},
                    "rotation": {"x": 0.0, "y": 0.0, "z": 0.0},
                    "mesh_bend": {"enabled": False}
                },
                "layering": {"z_index": "front"}
            }
            captions.append(caption_obj)
            word_index += 1

    return {
        "project_id": "temp_project",
        "language": "cs",
        "resolution": {"width": video_width, "height": video_height},
        "captions": captions
    }

def process_video(video_path: str, output_json_path: str):
    try:
        print(f"Loading Whisper model... (Using 'small' for lightning fast Czech transcription)")
        model = whisper.load_model("small") 
        
        with tempfile.TemporaryDirectory() as temp_dir:
            audio_path = os.path.join(temp_dir, "audio.wav")
            print("Extracting audio...")
            extract_audio(video_path, audio_path)
            
            print("Transcribing with word-level timestamps...")
            result = model.transcribe(audio_path, language="cs", word_timestamps=True)
            
            print("Generating IvCaptions JSON schema...")
            schema = generate_base_json(result)
            
            with open(output_json_path, 'w', encoding='utf-8') as f:
                json.dump(schema, f, ensure_ascii=False, indent=2)
                
            print(f"MVP JSON saved to {output_json_path}")
    except Exception as e:
        print(f"Transcription error: {e}")
        # Write error marker so API status can report failure instead of hanging!
        with open(f"{output_json_path}.error", "w", encoding='utf-8') as f:
            f.write(str(e))

if __name__ == "__main__":
    import sys
    print("MVP Transcriber Initialized.")
    video_file = sys.argv[1] if len(sys.argv) > 1 else "test.mov"
    output_file = sys.argv[2] if len(sys.argv) > 2 else "output_captions.json"
    process_video(video_file, output_file)
