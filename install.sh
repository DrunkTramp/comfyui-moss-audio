#!/usr/bin/env bash
# install.sh — One-command setup for comfyui-moss-audio
# Run from ComfyUI/ directory or set COMFY_ROOT
set -e

COMFY_ROOT="${COMFY_ROOT:-$(pwd)}"
MOSS_DIR="$COMFY_ROOT/models/moss-audio"
VENV="$MOSS_DIR/venv"

echo "=== comfyui-moss-audio installer ==="
echo "ComfyUI root: $COMFY_ROOT"
echo "MOSS dir:     $MOSS_DIR"
echo ""

# ── 1. Clone MOSS-Audio source ──────────────────────────────────────
if [ -f "$MOSS_DIR/src/src/modeling_moss_audio.py" ]; then
    echo "[1/4] MOSS-Audio source already present, skipping clone."
else
    echo "[1/4] Cloning MOSS-Audio source..."
    mkdir -p "$MOSS_DIR"
    git clone https://github.com/OpenMOSS/MOSS-Audio.git "$MOSS_DIR/src"
fi

# ── 2. Create standalone venv ───────────────────────────────────────
if [ -f "$VENV/bin/python" ]; then
    echo "[2/4] Standalone venv already exists, skipping."
else
    echo "[2/4] Creating standalone venv (Python 3.10+)..."
    python3 -m venv "$VENV"
fi

# ── 3. Install venv dependencies ────────────────────────────────────
echo "[3/4] Installing dependencies in standalone venv..."
# Detect CUDA version for proper PyTorch wheel. Defaults to CUDA 12.8.
CUDA_VER="${CUDA_VER:-cu128}"
"$VENV/bin/pip" install --quiet \
    torch torchaudio torchcodec --index-url "https://download.pytorch.org/whl/$CUDA_VER" \
    "transformers==4.57.1" \
    safetensors soundfile tiktoken einops scipy accelerate \
    numpy

# ── 4. Install caption CLI script ───────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/caption_cli.py" "$MOSS_DIR/caption_cli.py" 2>/dev/null && \
    echo "[4/4] CLI script installed." || \
    echo "[4/4] CLI script already in place."

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Download a model:"
echo "     cd $MOSS_DIR"
echo "     hf download OpenMOSS-Team/MOSS-Audio-4B-Instruct --local-dir MOSS-Audio-4B-Instruct"
echo ""
echo "  2. Restart ComfyUI"
echo ""
echo "  3. Add MOSS-Audio Model Loader + MOSS-Audio Caption nodes"
echo ""
echo "See README.md for more details."
