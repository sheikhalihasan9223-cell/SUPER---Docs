"""Install pinned official Upscayl binaries/models into the ignored runtime folder."""
import io
import os
from pathlib import Path
import platform
import urllib.request
import zipfile

root = Path(__file__).parent / 'runtime' / 'upscayl'
release = '20251207-174704'
system = {'Windows': 'windows', 'Linux': 'linux', 'Darwin': 'macos'}.get(platform.system())
if not system:
    raise SystemExit('Unsupported worker operating system')
url = f'https://github.com/upscayl/upscayl-ncnn/releases/download/{release}/upscayl-bin-{release}-{system}.zip'
root.mkdir(parents=True, exist_ok=True)
with urllib.request.urlopen(url, timeout=120) as response:
    archive = zipfile.ZipFile(io.BytesIO(response.read()))
for entry in archive.infolist():
    if entry.is_dir():
        continue
    target = (root / entry.filename).resolve()
    if root.resolve() not in target.parents:
        raise ValueError('Invalid archive path')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(archive.read(entry))
    if target.name == 'upscayl-bin' and os.name != 'nt':
        target.chmod(0o755)
models = root / 'models'
models.mkdir(exist_ok=True)
for name in ['upscayl-standard-4x.bin', 'upscayl-standard-4x.param']:
    url = f'https://raw.githubusercontent.com/upscayl/upscayl/v2.15.0/resources/models/{name}'
    with urllib.request.urlopen(url, timeout=120) as response:
        (models / name).write_bytes(response.read())
print('Upscayl engine and standard model installed. A Vulkan-compatible GPU is required.')
