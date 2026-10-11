"""Generate SUPER - Docs launcher artwork from simple geometric shapes."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parent.parent
image = Image.new('RGB', (1024, 1024), '#7428F5')
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((250, 170, 774, 850), radius=65, fill='white')
draw.rounded_rectangle((330, 285, 490, 390), radius=20, fill='#E7D5FF')
for y, end in [(490, 695), (565, 695), (640, 600)]:
    draw.rounded_rectangle((330, y, end, y + 32), radius=16, fill='#7428F5')
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    path = root / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path)
for size in [192, 512]:
    for suffix in ['', '-maskable']:
        image.resize((size, size), Image.Resampling.LANCZOS).save(root / f'web/icons/Icon{suffix}-{size}.png')
image.resize((32, 32), Image.Resampling.LANCZOS).save(root / 'web/favicon.png')
icons = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((icons / 'Contents.json').read_text())['images']:
    if 'filename' in entry:
        size = round(float(entry['size'].split('x')[0]) * float(entry['scale'].replace('x', '')))
        image.resize((size, size), Image.Resampling.LANCZOS).save(icons / entry['filename'])
