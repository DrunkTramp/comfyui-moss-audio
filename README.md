# comfyui-moss-audio

ComfyUI custom nodes for local audio captioning and style description using [MOSS-Audio](https://github.com/OpenMOSS/MOSS-Audio) models.

Two nodes, both under **audio/MOSS-Audio**:

- **MOSS-Audio Model Loader** — scans `models/moss-audio/` for installed models
- **MOSS-Audio Caption** — takes audio + prompt, outputs a text description

Inference runs in a **standalone venv** with transformers 4.57.1, avoiding conflicts with ComfyUI's transformers 5.x. The node communicates via subprocess — no dependency clashes.

---

## Quick Install (automatic)

```bash
cd ComfyUI/custom_nodes/comfyui-moss-audio
bash install.sh
```

Then download a model and restart ComfyUI (see below).

---

## Manual Install

### 1. Install this node

Drop `comfyui-moss-audio/` into `ComfyUI/custom_nodes/`.

ComfyUI dependency: `pip install soundfile` (in your ComfyUI venv).

### 2. Clone MOSS-Audio source

```bash
mkdir -p ComfyUI/models/moss-audio
cd ComfyUI/models/moss-audio
git clone https://github.com/OpenMOSS/MOSS-Audio.git src
```

### 3. Create standalone venv

```bash
python3 -m venv ComfyUI/models/moss-audio/venv
# Install torch with CUDA support (adjust cu128 to match your CUDA version)
ComfyUI/models/moss-audio/venv/bin/pip install \
    torch torchaudio torchcodec --index-url https://download.pytorch.org/whl/cu128 \
    "transformers==4.57.1" \
    safetensors soundfile tiktoken einops scipy accelerate numpy
```

### 4. Place CLI script

```bash
cp ComfyUI/custom_nodes/comfyui-moss-audio/caption_cli.py \
   ComfyUI/models/moss-audio/caption_cli.py
```

### 5. Download model weights

```bash
cd ComfyUI/models/moss-audio
hf download OpenMOSS-Team/MOSS-Audio-4B-Instruct --local-dir MOSS-Audio-4B-Instruct
```

> **Important:** Download ALL files. The model needs `model.safetensors.index.json`, `tokenizer_config.json`, `vocab.json`, `merges.txt`, and all config files — not just the `.safetensors` shards.

### 6. Restart ComfyUI

---

## Directory structure after setup

```
ComfyUI/
  models/
    moss-audio/
      venv/                          ← standalone Python with transformers 4.57.1
      src/                           ← MOSS-Audio git clone
      caption_cli.py                 ← CLI script called by the node
      MOSS-Audio-4B-Instruct/        ← model weights (any folder with config.json)
        config.json
        model-00001-of-00003.safetensors
        model-00002-of-00003.safetensors
        model-00003-of-00003.safetensors
        model.safetensors.index.json
        tokenizer_config.json
        vocab.json
        merges.txt
        ...
```

---

## Available Models

| Model | Params | Est. VRAM | HuggingFace |
|-------|--------|-----------|-------------|
| MOSS-Audio-4B-Instruct | ~4.6B | ~8-10 GB | [OpenMOSS-Team/MOSS-Audio-4B-Instruct](https://huggingface.co/OpenMOSS-Team/MOSS-Audio-4B-Instruct) |
| MOSS-Audio-4B-Thinking | ~4.6B | ~8-10 GB | [OpenMOSS-Team/MOSS-Audio-4B-Thinking](https://huggingface.co/OpenMOSS-Team/MOSS-Audio-4B-Thinking) |
| MOSS-Audio-8B-Instruct | ~8.6B | ~15-18 GB | [OpenMOSS-Team/MOSS-Audio-8B-Instruct](https://huggingface.co/OpenMOSS-Team/MOSS-Audio-8B-Instruct) |
| MOSS-Audio-8B-Thinking | ~8.6B | ~15-18 GB | [OpenMOSS-Team/MOSS-Audio-8B-Thinking](https://huggingface.co/OpenMOSS-Team/MOSS-Audio-8B-Thinking) |

**Recommendation:** 4B-Instruct on 16 GB GPUs. 8B models may OOM. Thinking variants give longer, more detailed output.

---

## Workflow

```
LoadAudio (from audiotools) ──→ MossAudioCaption ──→ ShowText
                                        ↑
                              MossAudioModelLoader
```

1. Add **MOSS-Audio Model Loader** → select a model from the dropdown
2. Add **MOSS-Audio Caption** → wire `moss_pipe` + `audio` + write a prompt
3. Queue

### Performance

- First run: ~30s (model loads into GPU)
- Subsequent runs: ~2-10s depending on audio length
- Peak VRAM: ~8-10 GiB (with default 8 GiB GPU budget)
- VRAM budget adjustable via `max_memory` in `caption_cli.py`

---

## Example prompts

| Task | Prompt |
|------|--------|
| Music analysis | `"Describe the musical style, mood, instrumentation, tempo, and any notable production elements in this audio."` |
| Instrument ID | `"What instruments are playing? Describe the genre and feel."` |
| Transcription | `"Transcribe the speech in this audio."` |
| Scene description | `"What is happening in this audio clip? Describe the scene."` |
| Speaker analysis | `"Describe the vocal style and emotional character of the speaker."` |

---

## Troubleshooting

**"No models found" in dropdown:**
Model folders must have `config.json` inside. Check `models/moss-audio/`.

**CLI fails with "zero-size array":**
Audio must be at least 0.5 seconds long. The feature extractor needs a minimum number of frames.

**OOM errors:**
Edit `caption_cli.py` and lower `max_memory={0: "8GiB"}` to `"6GiB"` or `"4GiB"`. More layers will run on CPU (slower, but fits).

**"MOSS-Audio CLI failed (exit 1)":**
Check that the standalone venv was created with `transformers==4.57.1`. Run `models/moss-audio/venv/bin/pip list | grep transformers` to verify.

---

## How it works

The node saves ComfyUI audio to a temp WAV file, then calls `caption_cli.py` via subprocess in a separate venv. The standalone venv has transformers 4.57.1 (which MOSS-Audio was trained on), while ComfyUI keeps transformers 5.x. The two never touch.

Output is JSON, parsed by the node and returned as a string.

---

## License

This node package: Apache 2.0  
MOSS-Audio models and source: Apache 2.0
# Comfy-Mossaudio
# Comfy-Mossaudio
