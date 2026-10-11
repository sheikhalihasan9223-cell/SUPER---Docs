import io
from pathlib import Path
from types import SimpleNamespace
import pytest
from PIL import Image
from fastapi.testclient import TestClient
import upscayl_service as engine
from app import app

def photo():
    out = io.BytesIO()
    Image.new('RGB', (24, 32), 'green').save(out, 'PNG')
    return out.getvalue()

def test_missing_engine_is_actionable(monkeypatch):
    monkeypatch.setattr(engine, 'configured', lambda: False)
    response = TestClient(app).post('/process/image_enhance', files={'files': ('photo.png', photo())})
    assert response.status_code == 422
    assert 'Upscayl is not installed' in response.json()['detail']

def test_enhancement_runs_engine_and_returns_verified_image(monkeypatch, tmp_path):
    binary = tmp_path / 'upscayl-bin.exe'
    binary.touch()
    monkeypatch.setattr(engine, 'engine_paths', lambda: (binary, tmp_path))
    monkeypatch.setattr(engine, 'configured', lambda: True)
    def run(args, **kwargs):
        assert '-n' in args and 'upscayl-standard-4x' in args
        assert kwargs['timeout'] == 100
        source = Path(args[args.index('-i') + 1])
        target = Path(args[args.index('-o') + 1])
        with Image.open(source) as im:
            im.resize((im.width * 2, im.height * 2)).save(target)
        return SimpleNamespace(returncode=0)
    monkeypatch.setattr(engine.subprocess, 'run', run)
    response = TestClient(app).post('/process/image_enhance', files={'files': ('photo.png', photo())})
    assert response.status_code == 200
    assert Image.open(io.BytesIO(response.content)).size == (48, 64)
    assert response.headers['x-output-name'] == 'enhanced-upscayl.png'
    assert not engine.GPU_JOB.locked()

def test_rejects_invalid_scale_and_oversized_input(monkeypatch):
    monkeypatch.setattr(engine, 'configured', lambda: True)
    with pytest.raises(ValueError, match='2x or 4x'):
        engine.enhance([photo()], {'upscale': '../bad'})
    with pytest.raises(ValueError, match='one photograph'):
        engine.enhance([photo(), photo()], {})

def test_failed_gpu_releases_lock(monkeypatch, tmp_path):
    monkeypatch.setattr(engine, 'configured', lambda: True)
    monkeypatch.setattr(engine, 'engine_paths', lambda: (tmp_path / 'engine', tmp_path))
    monkeypatch.setattr(engine.subprocess, 'run', lambda *a, **kw: SimpleNamespace(returncode=1))
    with pytest.raises(ValueError, match='Vulkan-compatible'):
        engine.enhance([photo()], {})
    assert not engine.GPU_JOB.locked()
