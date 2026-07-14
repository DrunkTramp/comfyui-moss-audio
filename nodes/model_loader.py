"""
MOSS-Audio Model Loader node for ComfyUI.
Scans models/moss-audio/ for installed models — no in-process loading.
The actual inference runs in a standalone venv via subprocess.
"""
import os
import folder_paths

MODELS_DIR = os.path.join(folder_paths.models_dir, "moss-audio")


def _scan_models():
    """Return {display_name: full_path} for each valid model directory."""
    if not os.path.isdir(MODELS_DIR):
        return {}
    found = {}
    for name in sorted(os.listdir(MODELS_DIR)):
        full = os.path.join(MODELS_DIR, name)
        if not os.path.isdir(full):
            continue
        if os.path.isfile(os.path.join(full, "config.json")):
            found[name] = full
    return found


class MossAudioModelLoader:
    """Selects a MOSS-Audio model from models/moss-audio/.

    The actual model runs in its own venv (transformers 4.57.1)
    to avoid conflicts with ComfyUI's transformers 5.x.
    """

    @classmethod
    def INPUT_TYPES(cls):
        models = _scan_models()
        if not models:
            models = {"(no models found — see README.md)": ""}
        return {
            "required": {
                "model": (list(models.keys()),),
            },
        }

    RETURN_TYPES = ("MOSS_AUDIO_PIPE",)
    RETURN_NAMES = ("moss_pipe",)
    FUNCTION = "load_model"
    CATEGORY = "audio/MOSS-Audio"

    def load_model(self, model):
        models = _scan_models()
        if model not in models or not models[model]:
            raise RuntimeError(
                "No MOSS-Audio models found in models/moss-audio/.\n"
                "See custom_nodes/comfyui-moss-audio/README.md for setup."
            )
        # Just return the model path — inference runs in subprocess
        return (models[model],)

    @classmethod
    def IS_CHANGED(cls, **kwargs):
        return kwargs.get("model", "")
