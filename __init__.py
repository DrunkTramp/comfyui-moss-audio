"""
comfyui-moss-audio — MOSS-Audio audio captioning nodes for ComfyUI.

Two nodes under audio/MOSS-Audio:
  MossAudioModelLoader  — select a model from models/moss-audio/
  MossAudioCaption      — describe audio using the selected model

Inference runs in a standalone venv (models/moss-audio/venv/) with
transformers 4.57.1 to avoid conflicts with ComfyUI's transformers 5.x.
"""
from .nodes.model_loader import MossAudioModelLoader
from .nodes.caption import MossAudioCaption

NODE_CLASS_MAPPINGS = {
    "MossAudioModelLoader": MossAudioModelLoader,
    "MossAudioCaption": MossAudioCaption,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "MossAudioModelLoader": "MOSS-Audio Model Loader",
    "MossAudioCaption": "MOSS-Audio Caption",
}
