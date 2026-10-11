import io
import zipfile
import pytest
from fastapi.testclient import TestClient
from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas
from app import app, process, page_indices


def fixture_pdf(pages=3):
    out = io.BytesIO()
    c = canvas.Canvas(out)
    for i in range(pages):
        c.drawString(50, 700, f'Page {i + 1} sample text')
        c.showPage()
    c.save()
    return out.getvalue()


def test_merge_and_page_order():
    a, b = fixture_pdf(2), fixture_pdf(1)
    data, _, _ = process('merge', [a, b], {})
    assert len(PdfReader(io.BytesIO(data)).pages) == 3
    data, _, _ = process('organize', [a], {'range': '2,1,2'})
    pages = PdfReader(io.BytesIO(data)).pages
    assert len(pages) == 3
    assert 'Page 2' in pages[0].extract_text()
    assert 'Page 1' in pages[1].extract_text()


def test_split_extract_rotate():
    source = fixture_pdf()
    data, _, _ = process('split', [source], {'range': '1,3'})
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        assert z.namelist() == ['page-1.pdf', 'page-3.pdf']
    data, _, _ = process('extract', [source], {'range': '2-3'})
    assert len(PdfReader(io.BytesIO(data)).pages) == 2
    data, _, _ = process('rotate', [source], {'range': '2', 'angle': 90})
    pages = PdfReader(io.BytesIO(data)).pages
    assert pages[0].rotation == 0
    assert pages[1].rotation == 90


def test_protect_unlock_wrong_password():
    locked, _, _ = process('protect', [fixture_pdf()], {'password': 'test-password'})
    reader = PdfReader(io.BytesIO(locked))
    assert reader.is_encrypted
    assert reader.decrypt('test-password')
    with pytest.raises(ValueError):
        process('unlock', [locked], {'password': 'wrong'})
    clear, _, _ = process('unlock', [locked], {'password': 'test-password'})
    assert not PdfReader(io.BytesIO(clear)).is_encrypted


def test_watermark_numbering_and_text():
    source = fixture_pdf()
    numbered, _, _ = process('numbers', [source], {'range': '2', 'position': 'Top right'})
    assert '2' in PdfReader(io.BytesIO(numbered)).pages[1].extract_text()
    marked, _, _ = process('watermark', [source], {'text': 'CONFIDENTIAL', 'opacity': .25})
    assert 'CONFIDENTIAL' in PdfReader(io.BytesIO(marked)).pages[0].extract_text()
    text, _, _ = process('text', [source], {})
    assert b'Page 1 sample text' in text


def test_compress_preserves_content():
    source = fixture_pdf()
    data, _, _ = process('compress', [source], {'compression': 'Recommended'})
    assert len(data) <= len(source)
    assert len(PdfReader(io.BytesIO(data)).pages) == 3


def test_render_and_repair():
    source = fixture_pdf(1)
    image, name, mime = process('pdf_jpg', [source], {})
    assert image.startswith(b'\xff\xd8') and name.endswith('.jpg') and mime == 'image/jpeg'
    data, _, _ = process('repair', [source], {})
    assert len(PdfReader(io.BytesIO(data)).pages) == 1


def test_ranges():
    assert page_indices('3,1-2', 3) == [2, 0, 1]
    for invalid in ['0', '4', '3-1', 'x', '1-2-3']:
        with pytest.raises(ValueError):
            page_indices(invalid, 3)


def test_http_contract():
    client = TestClient(app)
    response = client.post('/process/rotate', files=[('files', ('a.pdf', fixture_pdf(), 'application/pdf'))], data={'options': '{"angle": 180}'})
    assert response.status_code == 200
    assert response.headers['x-output-name'] == 'rotate.pdf'
    assert response.headers['cache-control'] == 'no-store'
    assert PdfReader(io.BytesIO(response.content)).pages[0].rotation == 180
    assert client.post('/process/ocr').status_code == 415
    assert client.post('/process/merge', files=[('files', ('a.pdf', b'not pdf'))]).status_code == 422


def test_hosted_worker_requires_its_private_secret(monkeypatch):
    monkeypatch.setenv('PROCESSOR_SHARED_SECRET', 'private-worker-secret')
    client = TestClient(app)
    denied = client.post('/process/rotate', files={'files': ('source.pdf', fixture_pdf())}, data={'options': '{"angle":90}'})
    assert denied.status_code == 401
    assert 'private-worker-secret' not in denied.text
    allowed = client.post('/process/rotate', headers={'X-Processor-Secret': 'private-worker-secret'}, files={'files': ('source.pdf', fixture_pdf())}, data={'options': '{"angle":90}'})
    assert allowed.status_code == 200
    assert PdfReader(io.BytesIO(allowed.content)).pages[0].rotation == 90
