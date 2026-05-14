import os
import sys

# Ensure local FFmpeg is in PATH for ffmpeg-python
ffmpeg_bin_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ffmpeg_extracted", "ffmpeg-8.1.1-essentials_build", "bin")
if os.path.exists(ffmpeg_bin_dir):
    os.environ["PATH"] += os.pathsep + ffmpeg_bin_dir

import cv2
import numpy as np
import torch
import ffmpeg

def generate_mask_video(input_video_path: str, output_mask_path: str):
    """
    Plně automatický proces maskování postav pro 'Iv-Layer':
    1. Použije ultrarychlý YOLOv8 na první snímek videa pro nalezení člověka.
    2. Získaný čtverec (Bounding Box) předá jako 'prompt' do SAM 2.
    3. SAM 2 model přesně ořízne obrys (vlasy, tělo) a protáhne masku celým videem.
    4. Výsledek se uloží jako černobílé video (člověk=bílá, pozadí=černá).
    """
    print(f"Starting auto-segmentation for {input_video_path}...")
    
    # Otevření videa
    cap = cv2.VideoCapture(input_video_path)
    ret, first_frame = cap.read()
    if not ret:
        print("Error: Nelze načíst vstupní video.")
        return None
        
    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    # KROK 1: YOLOv8 Detekce člověka
    print("Načítám YOLOv8n pro automatickou detekci postavy...")
    try:
        from ultralytics import YOLO
        yolo_model = YOLO("yolov8n.pt")
        # COCO class 0 je 'person'
        results = yolo_model(first_frame, classes=[0], max_det=1)
        
        if len(results) == 0 or len(results[0].boxes) == 0:
            print("YOLO: Člověk nenalezen. Používám záložní středový čtverec.")
            box = np.array([width*0.25, height*0.25, width*0.75, height*0.75])
        else:
            box = results[0].boxes[0].xyxy.cpu().numpy()[0]
            print(f"YOLO: Člověk nalezen v souřadnicích {box}")
    except ImportError:
        print("Upozornění: YOLOv8 (ultralytics) není nainstalováno. Používám středový čtverec.")
        box = np.array([width*0.25, height*0.25, width*0.75, height*0.75])

    # KROK 2: SAM 2 Segmentace
    print("Inicializace SAM 2 Video Predictor...")
    try:
        # Tento blok se reálně spustí, jakmile bude nainstalována knihovna sam2 a PyTorch
        from sam2.build_sam import build_sam2_video_predictor
        
        sam2_checkpoint = "sam2_hiera_small.pt"
        model_cfg = "sam2_hiera_s.yaml"
        
        predictor = build_sam2_video_predictor(model_cfg, sam2_checkpoint)
        inference_state = predictor.init_state(video_path=input_video_path)
        
        # Přidáme Bounding Box z YOLO jako instrukci do 1. snímku
        _, out_obj_ids, out_mask_logits = predictor.add_new_points_or_box(
            inference_state=inference_state,
            frame_idx=0,
            obj_id=1,
            box=box
        )
        
        temp_mask_path = output_mask_path + "_temp.mp4"
        print("SAM 2: Vyhlazuji masku po celém videu (Propagating)...")
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out_vid = cv2.VideoWriter(temp_mask_path, fourcc, fps, (width, height), isColor=False)
        
        # Získávání snímků masek
        for out_frame_idx, out_obj_ids, out_mask_logits in predictor.propagate_in_video(inference_state):
            # Převod logitů na binární obraz (nad nulou je bílá, pod nulou černá)
            mask = (out_mask_logits[0] > 0.0).cpu().numpy().squeeze()
            mask_img = (mask * 255).astype(np.uint8)
            out_vid.write(mask_img)
            
        out_vid.release()
        print("Maska vygenerována, spojuji do transparentního WebM...")
        
    except ImportError:
        print("Upozornění: SAM 2 ještě není v prostředí nainstalován (probíhá příprava).")
        print("Vytvářím testovací masku (zástupný soubor) pro dokončení pipeline.")
        
        temp_mask_path = output_mask_path + "_temp.mp4"
        # Vytvoření testovacího "dummy" videa
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out_vid = cv2.VideoWriter(temp_mask_path, fourcc, fps, (width, height), isColor=False)
        
        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            # Nakreslí bílý obdélník místo člověka
            mask_img = np.zeros((height, width), dtype=np.uint8)
            cv2.rectangle(mask_img, (int(box[0]), int(box[1])), (int(box[2]), int(box[3])), 255, -1)
            out_vid.write(mask_img)
            
        out_vid.release()
        
    cap.release()
    
    # Nyní použijeme FFmpeg pro spojení originálního videa a masky do WebM s alfakanálem
    print("Vytvářím transparentní WebM (Subject Extraction)...")
    video = ffmpeg.input(input_video_path)
    mask_stream = ffmpeg.input(temp_mask_path)
    subject = ffmpeg.filter([video, mask_stream], 'alphamerge')
    
    out = ffmpeg.output(
        subject, 
        output_mask_path, 
        vcodec='libvpx-vp9', 
        pix_fmt='yuva420p',
        deadline='realtime',
        **{'cpu-used': 8, 'auto-alt-ref': 0}
    )
    ffmpeg.run(out, overwrite_output=True, quiet=False)
    
    # Smazání dočasné masky
    if os.path.exists(temp_mask_path):
        os.remove(temp_mask_path)
        
    print(f"Transparent mask video saved to: {output_mask_path}")
    return output_mask_path

if __name__ == "__main__":
    pass
