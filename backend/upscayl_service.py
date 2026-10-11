"""Run the official Upscayl NCNN engine in an isolated per-request directory."""
import io
import os
from pathlib import Path
import subprocess
import tempfile
import threading
from PIL import Image, ImageOps

GPU_JOB = threading.Lock()
RUNTIME = Path(__file__).parent / 'runtime' / 'upscayl'

def engine_paths():
    override = os.getenv('UPSCAYL_BIN')
    candidates = sorted(RUNTIME.rglob('upscayl-bin.exe' if os.name == 'nt' else 'upscayl-bin')) if RUNTIME.exists() else []
    binary = Path(override) if override else (candidates[0] if candidates else None)
    models = Path(os.getenv('UPSCAYL_MODELS', str(RUNTIME / 'models')))
    return binary, models

def configured():
    binary, models = engine_paths()
    return bool(binary and binary.is_file() and (models / 'upscayl-standard-4x.bin').is_file() and (models / 'upscayl-standard-4x.param').is_file())

def enhance(files, options):
    if len(files) != 1:
        raise ValueError('Select one photograph at a time for Upscayl enhancement.')
    if not configured():
        raise ValueError('Upscayl is not installed on the processing worker. Use local enhancement or configure UPSCAYL_BIN and UPSCAYL_MODELS.')
    scale = options.get('upscale', 2)
    if type(scale) is not int or scale not in (2, 4):
        raise ValueError('Choose 2x or 4x enlargement.')
    try:
        with Image.open(io.BytesIO(files[0])) as original:
            if original.width * original.height * scale * scale > 32000000:
                raise ValueError('Use a smaller photograph. Enhanced output supports up to 32 megapixels.')
            image = ImageOps.exif_transpose(original).convert('RGB')
    except (OSError, Image.DecompressionBombError):
        raise ValueError('Select a valid JPG, PNG, or WebP photograph.') from None
    if not GPU_JOB.acquire(blocking=False):
        raise ValueError('The enhancement worker is busy. Please retry shortly.')
    try:
        binary, models = engine_paths()
        with tempfile.TemporaryDirectory(prefix='superdocs-upscayl-') as folder:
            source, result = Path(folder) / 'input.png', Path(folder) / 'enhanced.png'
            image.save(source)
            try:
                run = subprocess.run([str(binary.resolve()), '-i', str(source), '-o', str(result),
                    '-m', str(models.resolve()), '-n', 'upscayl-standard-4x', '-z', '4',
                    '-s', str(scale), '-t', '128', '-j', '1:1:1', '-f', 'png'],
                    cwd=folder, capture_output=True, timeout=100,
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
            except subprocess.TimeoutExpired:
                raise ValueError('Upscayl took too long. Try a smaller photograph or local enhancement.') from None
            except OSError:
                raise ValueError('Could not start Upscayl. Check the worker engine and Vulkan graphics drivers.') from None
            if run.returncode != 0 or not result.is_file():
                raise ValueError('Upscayl could not enhance this photo. The worker needs a Vulkan-compatible GPU and working graphics drivers.')
            with Image.open(result) as output:
                if output.size != (image.width * scale, image.height * scale):
                    raise ValueError('Upscayl returned an unexpected image size.')
                output.verify()
            data = result.read_bytes()
            if len(data) > 50 * 1024 * 1024:
                raise ValueError('Enhanced image is too large. Choose 2x or a smaller photograph.')
            return data, 'enhanced-upscayl.png', 'image/png'
    finally:
        GPU_JOB.release()
