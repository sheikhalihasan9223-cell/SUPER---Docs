ï»¿FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends libreoffice-writer libreoffice-calc libreoffice-impress tesseract-ocr tesseract-ocr-eng tesseract-ocr-ara tesseract-ocr-hin tesseract-ocr-spa tesseract-ocr-fra tesseract-ocr-por tesseract-ocr-ind tesseract-ocr-tur tesseract-ocr-urd fonts-dejavu fonts-liberation libvulkan1 mesa-vulkan-drivers && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
