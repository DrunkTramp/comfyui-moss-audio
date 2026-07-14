#!/usr/bin/env python3
"""MOSS-Audio CLI captioner. Called by ComfyUI node via subprocess.

Args:
    --model PATH       Model directory (e.g. models/moss-audio/MOSS-Audio-4B-Instruct)
    --audio PATH       Audio file to caption
    --prompt TEXT      What to ask about the audio
    --max-tokens N     Max new tokens (default 256)
    --temperature F    Sampling temperature (default 1.0)

Outputs the caption text to stdout.
"""
import argparse, json, sys, os, time, gc
import torch
import numpy as np

# Add MOSS-Audio repo root to path (parent of the src/ package)
# The MOSS-Audio code uses `from src.xxx` imports internally
REPO_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src")
sys.path.insert(0, REPO_ROOT)

from src.modeling_moss_audio import MossAudioModel
from src.processing_moss_audio import MossAudioProcessor
from src.audio_io import load_audio


def main():
    parser = argparse.ArgumentParser(description="MOSS-Audio captioner")
    parser.add_argument("--model", required=True, help="Model directory path")
    parser.add_argument("--audio", required=True, help="Audio file path")
    parser.add_argument("--prompt", default="Describe this audio.", help="Prompt text")
    parser.add_argument("--max-tokens", type=int, default=256)
    parser.add_argument("--temperature", type=float, default=1.0)
    parser.add_argument("--max-audio-secs", type=float, default=60.0,
                        help="Max audio duration in seconds (truncates longer files)")
    args = parser.parse_args()

    device = "cuda:0" if torch.cuda.is_available() else "cpu"
    dtype = torch.bfloat16 if device.startswith("cuda") else torch.float32

    # Memory config for 16GB VRAM
    if device.startswith("cuda"):
        os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")
        torch.cuda.empty_cache()
        gc.collect()

    # Load model
    model = MossAudioModel.from_pretrained(
        args.model, trust_remote_code=True,
        torch_dtype=dtype,
        device_map="auto",
        max_memory={0: "8GiB", "cpu": "32GiB"},
    )
    model.eval()

    # Load processor
    processor = MossAudioProcessor.from_pretrained(
        args.model, trust_remote_code=True, enable_time_marker=True,
    )

    # Load audio, truncate if needed
    raw_audio = load_audio(args.audio, sample_rate=processor.config.mel_sr)
    max_samples = int(args.max_audio_secs * processor.config.mel_sr)
    if len(raw_audio) > max_samples:
        raw_audio = raw_audio[:max_samples]

    # Process
    inputs = processor(text=args.prompt, audios=[raw_audio], return_tensors="pt")
    input_device = next(model.parameters()).device
    inputs = {k: v.to(input_device) if isinstance(v, torch.Tensor) else v
              for k, v in inputs.items()}
    if inputs.get("audio_data") is not None:
        inputs["audio_data"] = inputs["audio_data"].to(model.dtype)
    inputs["audio_input_mask"] = inputs["input_ids"] == processor.audio_token_id

    # Generate
    if device.startswith("cuda"):
        torch.cuda.empty_cache()
    with torch.no_grad():
        out = model.generate(
            **inputs,
            max_new_tokens=args.max_tokens,
            do_sample=args.temperature > 0,
            temperature=args.temperature,
            top_p=1.0,
            top_k=50,
            use_cache=True,
        )

    input_len = inputs["input_ids"].shape[1]
    caption = processor.decode(out[0, input_len:], skip_special_tokens=True)

    # Output as JSON with metadata
    result = {
        "caption": caption.strip(),
        "audio_duration_s": len(raw_audio) / processor.config.mel_sr,
        "tokens_generated": out.shape[1] - input_len,
    }
    print(json.dumps(result))


if __name__ == "__main__":
    main()
