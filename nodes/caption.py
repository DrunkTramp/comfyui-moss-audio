"""
MOSS-Audio Caption node for ComfyUI.
Calls the standalone venv CLI via subprocess to avoid transformers version conflicts.
"""
import json
import os
import subprocess
import tempfile
import torch
import soundfile as sf

import folder_paths

# Path to the CLI script and its venv
MOSS_DIR = os.path.join(folder_paths.models_dir, "moss-audio")
CLI_SCRIPT = os.path.join(MOSS_DIR, "caption_cli.py")
VENV_PYTHON = os.path.join(MOSS_DIR, "venv", "bin", "python")


class MossAudioCaption:
    """Generates a text caption/description for an audio file using MOSS-Audio.

    Runs MOSS-Audio in its own venv (transformers 4.57.1) via subprocess
    to avoid conflicts with ComfyUI's transformers 5.x.

    Connect a MossAudioModelLoader to select the model.
    Connect an AUDIO input (from LoadAudio or similar).
    The prompt describes what you want the model to analyze.
    """

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "moss_pipe": ("MOSS_AUDIO_PIPE",),
                "audio": ("AUDIO",),
                "prompt": ("STRING", {
                    "default": "Describe the musical style, mood, instrumentation, tempo, and any notable production elements in this audio.",
                    "multiline": True,
                }),
                "max_tokens": ("INT", {
                    "default": 256, "min": 64, "max": 1024, "step": 64,
                }),
                "temperature": ("FLOAT", {
                    "default": 0.7, "min": 0.01, "max": 2.0, "step": 0.01,
                }),
                "max_audio_secs": ("INT", {
                    "default": 60, "min": 5, "max": 300, "step": 5,
                    "tooltip": "Truncate audio longer than this (saves VRAM)",
                }),
            },
        }

    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("caption",)
    FUNCTION = "caption"
    CATEGORY = "audio/MOSS-Audio"

    def caption(self, moss_pipe, audio, prompt, max_tokens, temperature, max_audio_secs):
        # moss_pipe contains (model_path,) — just the selected model directory
        model_path = moss_pipe[0] if isinstance(moss_pipe, tuple) else moss_pipe

        # Save ComfyUI AUDIO to a temp WAV file
        waveform = audio["waveform"]
        sample_rate = audio["sample_rate"]

        # Handle batched audio: [B, C, samples] or [C, samples]
        if waveform.dim() == 3:
            waveform = waveform[0]  # take first batch
        # Convert stereo to mono if needed
        if waveform.dim() == 2 and waveform.shape[0] > 1:
            waveform = waveform.mean(dim=0, keepdim=True)  # [1, samples]
        elif waveform.dim() == 2 and waveform.shape[0] == 1:
            pass  # already mono [1, samples]
        elif waveform.dim() == 1:
            waveform = waveform.unsqueeze(0)  # [samples] -> [1, samples]

        audio_np = waveform.squeeze(0).cpu().numpy()

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            tmp_path = f.name
        try:
            sf.write(tmp_path, audio_np, sample_rate)

            cmd = [
                VENV_PYTHON, CLI_SCRIPT,
                "--model", model_path,
                "--audio", tmp_path,
                "--prompt", prompt,
                "--max-tokens", str(max_tokens),
                "--temperature", str(temperature),
                "--max-audio-secs", str(max_audio_secs),
            ]

            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=600,
                env={**os.environ, "HOME": os.environ.get("HOME", "/home/irreverend")},
            )

            if result.returncode != 0:
                raise RuntimeError(
                    f"MOSS-Audio CLI failed (exit {result.returncode}):\n"
                    f"STDERR: {result.stderr[-500:]}\n"
                    f"STDOUT: {result.stdout[-200:]}"
                )

            data = json.loads(result.stdout.strip().split("\n")[-1])
            caption = data.get("caption", "").strip()
            return (caption,)

        finally:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
