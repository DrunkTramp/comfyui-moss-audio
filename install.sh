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

# ── 0. Find Python 3.11 (system or uv) ──────────────────────────────
PYTHON_BIN=""
USE_UV=false

# Try system Python first
for candidate in python3.11 python3; do
    if command -v "$candidate" &>/dev/null; then
        ver=$("$candidate" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null)
        if [ "$ver" = "3.11" ]; then
            PYTHON_BIN="$candidate"
            break
        fi
    fi
done

if [ -n "$PYTHON_BIN" ]; then
    echo "Using system Python: $PYTHON_BIN (3.11)"
elif command -v uv &>/dev/null; then
    echo "Python 3.11 not found on system, but uv is available."
    if ! uv python list --only-installed 2>/dev/null | grep -q "3.11"; then
        echo "Installing Python 3.11 via uv..."
        uv python install 3.11
    fi
    USE_UV=true
    echo "Using uv-managed Python 3.11"
else
    echo "Python 3.11 not found on system."
    echo "uv can download and manage Python 3.11 automatically."
    read -p "Download and install uv? (y/N): " choice
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        echo "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        # Add uv to PATH for this session
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
        if command -v uv &>/dev/null; then
            echo "uv installed. Installing Python 3.11..."
            uv python install 3.11
            USE_UV=true
            echo "Using uv-managed Python 3.11"
        else
            echo "ERROR: uv installation failed. Install Python 3.11 manually."
            echo "  See: https://astral.sh/uv/  or  https://python.org"
            exit 1
        fi
    else
        echo "ERROR: Python 3.11 is required. Install it manually or rerun with 'y' to auto-install."
        echo "  https://astral.sh/uv/  or  https://python.org"
        exit 1
    fi
fi

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
    echo "[2/4] Creating standalone venv (Python 3.11)..."
    if [ "$USE_UV" = true ]; then
        uv venv --python 3.11 "$VENV"
    else
        "$PYTHON_BIN" -m venv "$VENV"
    fi
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
