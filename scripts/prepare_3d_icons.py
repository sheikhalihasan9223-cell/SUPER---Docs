"""Package ImageGen's 3D tool assets for Flutter while preserving transparency.

Source paths and the exact prompts are recorded in source-manifest.json.
Original PNGs stay untouched; the app gets compact, uniform display copies.
"""
import json
import shutil
import zipfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parent.parent
manifest = json.loads((ROOT / 'output/imagegen/source-manifest.json').read_text(encoding='utf-8-sig'))
assets = ROOT / 'assets/tool_icons_3d'
originals = ROOT / 'output/imagegen/tool-icons-3d/originals'
assets.mkdir(parents=True, exist_ok=True)
originals.mkdir(parents=True, exist_ok=True)
records = []
for record in manifest:
    source = Path(record['source_path'])
    image = Image.open(source).convert('RGBA')
    if image.getchannel('A').getextrema()[0] != 0:
        raise ValueError(f"{record['id']}: generated image has no transparent pixels")
    shutil.copy2(source, originals / f"{record['id']}.png")
    # Export sizing only: no repainting, background removal, or creative edits.
    image.thumbnail((512, 340), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (512, 340), (0, 0, 0, 0))
    canvas.alpha_composite(image, ((512-image.width)//2, (340-image.height)//2))
    canvas.save(assets / f"{record['id']}.png", optimize=True)
    records.append(record)
font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 16)
columns = 4
width, height = 320, 246
sheet = Image.new('RGB', (columns*width, ((len(records)+columns-1)//columns)*height), '#F8F6FF')
draw = ImageDraw.Draw(sheet)
for i, record in enumerate(records):
    image = Image.open(assets / f"{record['id']}.png")
    image.thumbnail((300, 208), Image.Resampling.LANCZOS)
    x,y = (i%columns)*width, (i//columns)*height
    sheet.paste(image, (x+(width-image.width)//2, y+(208-image.height)//2), image)
    draw.text((x+width/2,y+224), record['name'], font=font, fill='#302139', anchor='mm')
sheet.save(ROOT / 'output/imagegen/tool-icons-3d/catalog-preview.png')
with zipfile.ZipFile(ROOT / 'output/imagegen/tool-icons-3d.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for record in records:
        archive.write(assets / f"{record['id']}.png", f"{record['id']}.png")
    archive.write(ROOT / 'output/imagegen/tool-icons-3d/catalog-preview.png', 'catalog-preview.png')
    archive.write(ROOT / 'output/imagegen/source-manifest.json', 'source-manifest.json')
print(f'Prepared {len(records)} 3D icons, transparent app exports, untouched originals, and a download archive.')
