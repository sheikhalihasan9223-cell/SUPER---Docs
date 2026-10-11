from pathlib import Path
import urllib.request
folder=Path('backend/runtime/tesseract/tessdata')
for language in ['ara','hin','spa','fra','por','ind','tur','urd']:
    target=folder/f'{language}.traineddata'
    if not target.exists():
        urllib.request.urlretrieve(f'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main/{language}.traineddata',target)
        print(f'Installed OCR language: {language}',flush=True)
