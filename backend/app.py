"""Development PDF service. Temporary Office/OCR files are cleaned after processing."""
from contextlib import closing
import asyncio
import io
import json
import os
import secrets
import zipfile
from email.parser import BytesParser
from email.policy import default
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas
from advanced import ADVANCED, OFFICE_INPUTS, process_advanced, capability_details, searchable_pdf

from upscayl_service import configured, enhance
AI_TOOLS = {"image_enhance"}

app = FastAPI(title='SUPER Docs processing service', version='0.1.0')
app.add_middleware(CORSMiddleware,
    allow_origins=os.getenv('ALLOWED_ORIGINS', 'http://localhost:8080,http://127.0.0.1:8080').split(','),
    allow_methods=['GET', 'POST'], allow_headers=['Content-Type', 'X-Processor-Secret'], expose_headers=['X-Output-Name'])
MAX_FILE = 25 * 1024 * 1024
MAX_TOTAL = 50 * 1024 * 1024
MAX_PAGES = 500
slots = asyncio.Semaphore(2)
SUPPORTED = {'merge', 'split', 'organize', 'rotate', 'extract', 'compress', 'repair', 'pdf_jpg', 'text', 'numbers', 'watermark', 'protect', 'unlock'} | ADVANCED | AI_TOOLS


def page_indices(value, count):
    if not value or not str(value).strip():
        return list(range(count))
    result = []
    try:
        for part in str(value).split(','):
            bounds = part.strip().split('-')
            if len(bounds) > 2:
                raise ValueError()
            start = int(bounds[0])
            end = int(bounds[-1])
            if start < 1 or end < start or end > count:
                raise ValueError()
            result.extend(range(start - 1, end))
            if len(result) > MAX_PAGES:
                raise ValueError()
    except (ValueError, TypeError):
        raise ValueError(f'Use page ranges such as 1-3,5 within 1-{count}.') from None
    return result


def reader_for(data, password):
    reader = PdfReader(io.BytesIO(data), strict=False)
    if reader.is_encrypted and (not password or not reader.decrypt(password)):
        raise ValueError('This PDF needs its correct password. Use Unlock PDF first.')
    if len(reader.pages) > MAX_PAGES:
        raise ValueError(f'Use a PDF with at most {MAX_PAGES} pages.')
    if not reader.pages:
        raise ValueError('This PDF contains no readable pages.')
    return reader


def write_pdf(writer):
    out = io.BytesIO()
    writer.write(out)
    return out.getvalue()


def zip_outputs(outputs):
    out = io.BytesIO()
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, data in outputs:
            archive.writestr(name, data)
    return out.getvalue()


def process(tool, files, options, filenames=None):
    if tool == 'image_enhance':
        return enhance(files, options)
    if tool in ADVANCED:
        return process_advanced(tool, files, options, filenames)
    if tool not in SUPPORTED:
        raise ValueError('This tool is not available in this release.')
    if not 1 <= len(files) <= 5:
        raise ValueError('Select between one and five PDFs.')
    if tool == 'merge' and len(files) < 2:
        raise ValueError('Merge requires at least two PDFs.')
    if tool != 'merge' and len(files) != 1:
        raise ValueError('This tool accepts one PDF at a time.')
    if any(len(data) > MAX_FILE for data in files) or sum(map(len, files)) > MAX_TOTAL:
        raise ValueError('File limit is 25 MB each and 50 MB total.')
    password = str(options.get('password', ''))
    # A Protect password is the new password, never an input decryption password.
    readers = [reader_for(data, '' if tool == 'protect' else password) for data in files]
    if sum(len(r.pages) for r in readers) > MAX_PAGES:
        raise ValueError(f'Total page limit is {MAX_PAGES}.')
    reader = readers[0]
    indices = page_indices(options.get('range', ''), len(reader.pages))
    if tool == 'text':
        text = '\n\n'.join(reader.pages[i].extract_text() or '' for i in indices)
        if not text.strip():
            recognized = searchable_pdf(files[0], options)
            recovered = PdfReader(io.BytesIO(recognized))
            text = '\n\n'.join(p.extract_text() or '' for p in recovered.pages)
            if not text.strip():
                raise ValueError('OCR could not find readable text. Try a clearer scan.')
        return text.encode('utf-8'), 'text.txt', 'text/plain; charset=utf-8'
    if tool == 'split':
        outputs = []
        for i in indices:
            writer = PdfWriter()
            writer.add_page(reader.pages[i])
            outputs.append((f'page-{i + 1}.pdf', write_pdf(writer)))
        return zip_outputs(outputs), 'split-pages.zip', 'application/zip'
    if tool == 'pdf_jpg':
        import pypdfium2 as pdfium
        quality = max(10, min(100, int(options.get('quality', 80))))
        outputs = []
        with closing(pdfium.PdfDocument(files[0], password=password or None)) as document:
            for i in indices:
                with closing(document[i]) as page:
                    width, height = page.get_size()
                    if width <= 0 or height <= 0 or width * height * 4 > 30_000_000:
                        raise ValueError('Page dimensions are too large for image export.')
                    bitmap = page.render(scale=2)
                    try:
                        image = bitmap.to_pil()
                        out = io.BytesIO()
                        image.convert('RGB').save(out, 'JPEG', quality=quality)
                        outputs.append((f'page-{i + 1}.jpg', out.getvalue()))
                    finally:
                        bitmap.close()
        if len(outputs) == 1:
            return outputs[0][1], outputs[0][0], 'image/jpeg'
        return zip_outputs(outputs), 'pdf-images.zip', 'application/zip'
    writer = PdfWriter()
    if tool == 'merge':
        for r in readers:
            for page in r.pages:
                writer.add_page(page)
    elif tool in {'extract', 'organize'}:
        for i in indices:
            writer.add_page(reader.pages[i])
    else:
        for page in reader.pages:
            writer.add_page(page)
    if tool == 'rotate':
        angle = int(options.get('angle', 90))
        if angle not in (90, 180, 270):
            raise ValueError('Rotation must be 90, 180, or 270 degrees.')
        for i in indices:
            writer.pages[i].rotate(angle)
    if tool in {'numbers', 'watermark'}:
        for i in indices:
            page = writer.pages[i]
            page.transfer_rotation_to_content()
            width, height = float(page.mediabox.width), float(page.mediabox.height)
            out = io.BytesIO()
            overlay = canvas.Canvas(out, pagesize=(width, height))
            if tool == 'watermark':
                text = str(options.get('text', '')).strip()
                if not text or len(text) > 120:
                    raise ValueError('Use watermark text between 1 and 120 characters.')
                overlay.setFillAlpha(max(.05, min(1, float(options.get('opacity', .25)))))
                overlay.setFont('Helvetica-Bold', min(44, width / max(1, len(text) * .65)))
                overlay.translate(width / 2, height / 2)
                overlay.rotate(35)
                overlay.drawCentredString(0, 0, text)
            else:
                position = str(options.get('position', 'Bottom center')).lower()
                y = height - 28 if position.startswith('top') else 24
                overlay.setFont('Helvetica', 11)
                if 'left' in position:
                    overlay.drawString(28, y, str(i + 1))
                elif 'right' in position:
                    overlay.drawRightString(width - 28, y, str(i + 1))
                else:
                    overlay.drawCentredString(width / 2, y, str(i + 1))
            overlay.save()
            page.merge_page(PdfReader(out).pages[0])
    if tool == 'compress':
        level = options.get('compression', 'Recommended')
        if level not in {'Low', 'Recommended', 'Extreme'}:
            raise ValueError('Invalid compression level.')
        for page in writer.pages:
            page.compress_content_streams()
            if level != 'Low':
                for image in list(page.images):
                    try:
                        image.replace(image.image, quality=80 if level == 'Recommended' else 45)
                    except (ValueError, OSError, AttributeError):
                        # Some image masks cannot safely be recompressed.
                        pass
        writer.compress_identical_objects(remove_identicals=True, remove_orphans=True)
    if tool == 'protect':
        if not password or len(password.encode('utf-8')) > 127:
            raise ValueError('Use a password between 1 and 127 UTF-8 bytes.')
        writer.encrypt(user_password=password, owner_password=secrets.token_urlsafe(32), algorithm='AES-256')
    # Unlock, repair, and other tools reserialize without retaining encryption.
    output = write_pdf(writer)
    if tool == 'compress' and len(output) >= len(files[0]):
        return files[0], 'compressed.pdf', 'application/pdf'
    return output, f'{tool}.pdf', 'application/pdf'


@app.get('/health')
def health():
    return {'status': 'ok', 'tools': sorted(SUPPORTED), 'storage': 'transient', 'engines': capability_details(), 'upscayl': {'configured': configured(), 'tools': sorted(AI_TOOLS)}}


@app.post('/process/{tool}')
async def process_endpoint(tool: str, request: Request):
    worker_secret = os.getenv('PROCESSOR_SHARED_SECRET', '')
    if worker_secret and not secrets.compare_digest(request.headers.get('x-processor-secret', ''), worker_secret):
        raise HTTPException(401, 'Processing worker authorization required.')
    if tool not in SUPPORTED:
        raise HTTPException(422, 'Tool not enabled in this release.')
    content_type = request.headers.get('content-type', '')
    if not content_type.startswith('multipart/form-data'):
        raise HTTPException(415, 'Send multipart/form-data.')
    if slots.locked():
        raise HTTPException(429, 'The processor is busy. Please retry shortly.')
    async with slots:
        body = bytearray()
        async for chunk in request.stream():
            body.extend(chunk)
            if len(body) > MAX_TOTAL + 4 * 1024 * 1024:
                raise HTTPException(413, 'Upload exceeds the 50 MB total limit.')
        try:
            message = BytesParser(policy=default).parsebytes(
                f'Content-Type: {content_type}\r\nMIME-Version: 1.0\r\n\r\n'.encode() + bytes(body))
            files, filenames, options = [], [], {}
            for part in message.iter_parts():
                name = part.get_param('name', header='content-disposition')
                data = part.get_payload(decode=True)
                if name == 'files':
                    if not data or (tool not in set(OFFICE_INPUTS) | AI_TOOLS and b'%PDF-' not in data[:1024]):
                        raise ValueError('Select valid PDF files.')
                    files.append(data)
                    filenames.append(part.get_filename() or 'document.pdf')
                elif name == 'options':
                    if len(data) > 3*1024*1024:
                        raise ValueError('Options are too large.')
                    options = json.loads(data)
            if not isinstance(options, dict):
                raise ValueError('Options must be a JSON object.')
            output, name, mime = await asyncio.to_thread(process, tool, files, options, filenames)
            return Response(output, media_type=mime, headers={'X-Output-Name': name, 'Cache-Control': 'no-store', 'Content-Disposition': f'attachment; filename="{name}"'})
        except (ValueError, TypeError, KeyError, OverflowError) as exc:
            raise HTTPException(422, str(exc)) from None
        except Exception:
            # Never return document contents, passwords, or engine internals.
            raise HTTPException(422, 'Unable to process this PDF. It may be damaged or unsupported.') from None

