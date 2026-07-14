# comfyui-moss-audio

ComfyUI custom nodes for local audio captioning and style description using [MOSS-Audio](https://github.com/OpenMOSS/MOSS-Audio) models.

Two nodes, both under **audio/MOSS-Audio**:

- **MOSS-Audio Model Loader** — scans `ComfyUI/models/moss-audio/` for installed models
- **MOSS-Audio Caption** — takes audio + prompt, outputs a text description

Inference runs in a **standalone venv** with transformers 4.57.1, avoiding conflicts with ComfyUI's transformers 5.x. The node communicates via subprocess — no dependency clashes.

---

## Quick Install (automatic)

The install scripts handle everything — cloning MOSS-Audio source, creating a standalone Python 3.11 venv, and installing dependencies. The venv goes into `ComfyUI/models/moss-audio/venv/`.

**Requires Python 3.11 specifically.** If it's not on your system, the installer will offer to download [uv](https://docs.astral.sh/uv/) — a single-binary Python version manager. uv will download and manage Python 3.11 for you automatically, no manual installation needed.

### Linux

```bash
cd ComfyUI/custom_nodes/comfyui-moss-audio
bash install.sh
```

### Windows

```batch
cd ComfyUI\custom_nodes\comfyui-moss-audio
install.bat
```

Then download a model and restart ComfyUI (see below).

---

## Manual Install

### 1. Install this node

Drop the `comfyui-moss-audio/` folder into `ComfyUI/custom_nodes/`.

**Linux:** `pip install soundfile` in your ComfyUI venv.
**Windows:** Same — `pip install soundfile` in your ComfyUI venv (Python or py -3).

### 2. Clone MOSS-Audio source

**Linux:**
```bash
mkdir -p ComfyUI/models/moss-audio
cd ComfyUI/models/moss-audio
git clone https://github.com/OpenMOSS/MOSS-Audio.git src
```

**Windows:**
```batch
mkdir ComfyUI\models\moss-audio
cd /d ComfyUI\models\moss-audio
git clone https://github.com/OpenMOSS/MOSS-Audio.git src
```

### 3. Create standalone venv (Python 3.11)

The standalone venv must use **Python 3.11** — newer versions won't work. If you don't have 3.11 installed, you can use uv:

```bash
# Install uv if you don't have it: https://docs.astral.sh/uv/
uv python install 3.11
uv venv --python 3.11 ComfyUI/models/moss-audio/venv
```

**Linux (with system Python 3.11):**
```bash
python3.11 -m venv ComfyUI/models/moss-audio/venv
# Adjust cu128 to match your CUDA version (cu121, cu124, cu126, cu128)
ComfyUI/models/moss-audio/venv/bin/pip install \
    torch torchaudio torchcodec --index-url https://download.pytorch.org/whl/cu128 \
    "transformers==4.57.1" \
    safetensors soundfile tiktoken einops scipy accelerate numpy
```

**Windows (with system Python 3.11):**
```batch
python -m venv ComfyUI\models\moss-audio\venv
:: Adjust cu128 to match your CUDA version (cu121, cu124, cu126, cu128)
ComfyUI\models\moss-audio\venv\Scripts\pip install ^
    torch torchaudio torchcodec --index-url https://download.pytorch.org/whl/cu128 ^
    "transformers==4.57.1" ^
    safetensors soundfile tiktoken einops scipy accelerate numpy
```

### 4. Place CLI script

**Linux:**
```bash
cp ComfyUI/custom_nodes/comfyui-moss-audio/caption_cli.py \
   ComfyUI/models/moss-audio/caption_cli.py
```

**Windows:**
```batch
copy ComfyUI\custom_nodes\comfyui-moss-audio\caption_cli.py ComfyUI\models\moss-audio\caption_cli.py
```

### 5. Download model weights

Needs `huggingface-cli` installed (`pip install huggingface-hub`).

**Linux:**
```bash
cd ComfyUI/models/moss-audio
hf download OpenMOSS-Team/MOSS-Audio-4B-Instruct --local-dir MOSS-Audio-4B-Instruct
```

**Windows:**
```batch
cd /d ComfyUI\models\moss-audio
hf download OpenMOSS-Team/MOSS-Audio-4B-Instruct --local-dir MOSS-Audio-4B-Instruct
```

### 6. Restart ComfyUI

---

## Where model files go

The node expects models under `ComfyUI/models/moss-audio/`. Your final folder structure should look like this:

```
ComfyUI/
└── models/
    └── moss-audio/                    ← all MOSS stuff lives here
        ├── venv/                      ← standalone Python + transformers 4.57.1
        │   └── ...
        ├── src/                       ← MOSS-Audio source code (git clone)
        │   ├── src/
        │   ├── inference/
        │   └── ...
        ├── caption_cli.py             ← CLI script (copied from custom_nodes)
        └── MOSS-Audio-4B-Instruct/    ← model weights folder (you name this)
            ├── config.json            ← REQUIRED — node detects models by this
            ├── model-00001-of-00003.safetensors
            ├── model-00002-of-00003.safetensors
            ├── model-00003-of-00003.safetensors
            ├── model.safetensors.index.json
            ├── tokenizer_config.json
            ├── vocab.json
            ├── merges.txt
            └── ... (any other .json, .txt, .model files)
```

**Important rules:**
- The model folder name doesn't matter — the node scans `models/moss-audio/` for any subfolder containing `config.json`
- You can have multiple model folders here (e.g. `MOSS-Audio-4B-Instruct/` and `MOSS-Audio-4B-Thinking/`) and switch between them in the node dropdown
- Custom nodes don't go here — the node itself stays in `custom_nodes/comfyui-moss-audio/`
- If the dropdown says **"No models found"**, the model folder is missing `config.json` or isn't inside `models/moss-audio/`

### What "download ALL files" means

When you use `hf download`, it downloads everything. But if you copy files manually or from another machine, you must include **every** file in the HuggingFace repo — not just the `.safetensors` shards. The model will fail silently if any of these are missing:

| File | What it is |
|------|-----------|
| `config.json` | Model architecture definition |
| `model.safetensors.index.json` | Tells PyTorch which shard contains which layer |
| `model-00001-of-00003.safetensors` | Weight shard 1 |
| `model-00002-of-00003.safetensors` | Weight shard 2 |
| `model-00003-of-00003.safetensors` | Weight shard 3 |
| `tokenizer_config.json` | Tokenizer settings |
| `vocab.json` | Token vocabulary |
| `merges.txt` | BPE merges |
| `special_tokens_map.json` | Special token definitions |
| `tokenizer.json` | Full tokenizer (used by some pipelines) |
| `generation_config.json` | Generation parameters |

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
Model folders must have `config.json` inside. Check `ComfyUI/models/moss-audio/` — the model folder goes *there*, not in `custom_nodes/`. See the directory structure section above.

**CLI fails with "zero-size array":**
Audio must be at least 0.5 seconds long. The feature extractor needs a minimum number of frames.

**OOM errors:**
Edit `caption_cli.py` and lower `max_memory={0: "8GiB"}` to `"6GiB"` or `"4GiB"`. More layers will run on CPU (slower, but fits).

**"MOSS-Audio CLI failed (exit 1)":**
Check that the standalone venv was created with Python 3.11 and `transformers==4.57.1`:

**Linux:** `models/moss-audio/venv/bin/python --version` and `models/moss-audio/venv/bin/pip list | grep transformers`
**Windows:** `models\moss-audio\venv\Scripts\python --version` and `models\moss-audio\venv\Scripts\pip list | findstr transformers`

**Windows "git not found":**
Install [Git for Windows](https://git-scm.com/download/win) and make sure "Git from the command line" is selected during setup.

**Windows "python not found":**
Install Python 3.11 from [python.org](https://python.org). Check "Add Python to PATH" during installation.

---

## How it works

The node saves ComfyUI audio to a temp WAV file, then calls `caption_cli.py` via subprocess in a separate venv. The standalone venv has transformers 4.57.1 (which MOSS-Audio was trained on), while ComfyUI keeps transformers 5.x. The two never touch.

Output is JSON, parsed by the node and returned as a string.

---

## License

This node package: Apache 2.0  
MOSS-Audio models and source: Apache 2.0
