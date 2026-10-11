"""Smoke-test the live local preview and PDF processor without storing documents."""
import io
import httpx
from pypdf import PdfReader
from reportlab.pdfgen import canvas
health = httpx.get('http://127.0.0.1:8000/health').json()
assert health['status'] == 'ok'
preview = httpx.get('http://127.0.0.1:8080')
assert preview.status_code == 200 and 'SUPER - Docs' in preview.text
out = io.BytesIO()
c = canvas.Canvas(out)
c.drawString(50, 700, 'SUPER - Docs live service smoke test')
c.save()
result = httpx.post('http://127.0.0.1:8000/process/merge', files=[('files', ('one.pdf', out.getvalue(), 'application/pdf')), ('files', ('two.pdf', out.getvalue(), 'application/pdf'))], data={'options': '{}'}, timeout=30)
assert result.status_code == 200, result.text
assert len(PdfReader(io.BytesIO(result.content)).pages) == 2
print('Preview HTTP 200; processor healthy; live multipart merge produced two valid pages.')
