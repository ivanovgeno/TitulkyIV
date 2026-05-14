# IvCaptions Architecture Blueprint

## System Overview
IvCaptions operates on a Client-Server model where resource-intensive tasks (AI processing, rendering) are offloaded to a high-performance Python backend, while the Flutter client manages the user interface, video preview, and styling states.

## Component Flow

### 1. Flutter Client (iOS, Android, Web)
- **UI:** Custom video player with timeline scrubbing.
- **State:** Manages the `caption_schema.json` representing all captions, styles, and 3D transforms.
- **Preview Engine:** Visually simulates 3D text rotation and mesh bending over the video before final render.

### 2. Python FastAPI Backend
- **Transcription (Whisper Large-v3/WhisperX):** Processes audio to extract exact word-level timestamps, optimized for Czech language structure and diacritics.
- **Segmentation (SAM 2):** Generates high-quality alpha masks ("Iv-Layer") to place text behind human subjects.
- **3D Render Engine:** Headless engine (e.g., PyOpenGL or scripted Blender) to convert 2D text into 3D space with Bezier curves based on JSON parameters, outputting a transparent image sequence.
- **Compositing (FFmpeg):** Combines the original video, the generated 3D text layer, the SAM 2 mask (to clip text behind the subject), and mixed audio (original + SFX triggers).

## API Endpoints (Conceptual)

- `POST /api/v1/process/transcribe` -> Upload video/audio, returns initial JSON.
- `POST /api/v1/process/segment` -> Upload video, returns SAM 2 alpha mask data.
- `POST /api/v1/render/final` -> Upload final JSON + video, triggers rendering pipeline, returns MP4.
