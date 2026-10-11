# SUPER - Docs

Flutter app built from the supplied All-in-One PDF, Image & Scanner PRD. This is an executable MVP with working document operations, not the full production release described by the PRD.

## Run on this computer

The Flutter dependencies and a workspace-local Python environment are already installed.

Start the PDF service in one PowerShell terminal:

```powershell
cd 'C:\ALI - Docs'
backend/.venv/Scripts/python.exe -m uvicorn app:app --app-dir backend --host 127.0.0.1 --port 8000 --no-access-log
```

Start Flutter in another terminal:

```powershell
cd 'C:\ALI - Docs'
flutter run -d chrome --web-port 8080
```

Or serve the compiled release:

```powershell
backend/.venv/Scripts/python.exe -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

Open http://127.0.0.1:8080. Local image tools and PDF creation do not need the PDF service. The service's health endpoint is http://127.0.0.1:8000/health.

## Fresh setup

Flutter 3.44 / Dart 3.12 or compatible, plus Python 3.12+:

```powershell
flutter pub get
py -m venv backend/.venv
backend/.venv/Scripts/python.exe -m pip install -r backend/requirements.txt
```

Office conversion requires LibreOffice; OCR requires Tesseract with the selected language data. This workspace already includes both under `backend/runtime`. For a fresh Windows setup, install LibreOffice and Tesseract, then set `SOFFICE_PATH` and `TESSERACT_PATH` to their executables if they are not on PATH. `scripts/install_ocr_languages.py` downloads the supported language data into the workspace Tesseract runtime. The `/health` response reports `engines.office` and `engines.ocr`.

A Dockerfile is supplied in `backend`. Docker Desktop must be running before using it:

```powershell
docker build -t ali-docs-processor backend
docker run --rm -p 127.0.0.1:8000:8000 ali-docs-processor
```

## Implemented scope

| Area | Working features |
| --- | --- |
| Navigation | PDF tools, Image tools, Scanner, My files; desktop sidebar and mobile bottom navigation |
| Discovery | All 24 PDF tools and 4 image tools from the checklist, category filters, search, persistent tool favorites |
| PDF service | Merge in selected order; split into single-page PDFs in ZIP; extract pages; organize via explicit page order; rotate selected pages; compress streams and compatible images; best-effort reserialization/repair; PDF to JPG; extract selectable text; page numbers in 6 positions; text watermark; AES-256 protect; password-based unlock |
| Office conversion | DOC/DOCX, PPT/PPTX, XLS/XLSX to PDF using LibreOffice; PDF to editable DOCX, XLSX, and PPTX |
| OCR | Searchable PDF in English, Arabic, Hindi, Spanish, French, Portuguese, Indonesian, Turkish, and Urdu; scanned-PDF fallback for Office exports; maximum 40 scanned pages |
| Edit and sign | PDF page preview and tap placement; text, highlight, rectangle, visual whiteout; typed, drawn, camera-captured, or uploaded visible signatures; full-screen editor with move/resize/delete handles and undo/redo |
| Local image tools | Batch compression to JPEG; JPG conversion; conversion to PNG/GIF/BMP/TIFF; width-based resize with preserved aspect ratio; EXIF stripping; ZIP output for batches |
| Local PDF creation | Images to A4/Letter PDF; basic text-to-PDF |
| Scanner | In-app camera preview, flash, gallery import, Single/Multi capture and ID framing; dark crop editor with draggable corners/edges, rotate, replace, full-page reset and best-effort automatic crop; perspective correction; Original/Auto/Magic Color/Black & White/Grayscale filters; multipage session; reorder/delete/edit pages; local A4 PDF export |
| Result flow | Dedicated conversion completion screen with file summary, View PDF, Share, Save to Files, More actions, local history, and next-tool actions |
| My files | Search, favorite, rename, delete, reopen, export |
| Profile | Google account details, saved files, cloud sync, sign out, and persistent dark mode |
| Appearance | Floating frosted-glass navigation, translucent cards and headers, lavender/blue gradient backgrounds, and coordinated light/dark surfaces |

All 28 catalog tools are enabled. Office conversion, OCR, editing, and signing use the processing service.

## PRD gaps / next release work

- PDF-to-Word reconstructs text and detected tables; exact source layout is not guaranteed. PDF-to-Excel extracts detected tables with a text-row fallback. PDF-to-PowerPoint supports faithful page images or basic editable text.
- Editing adds text, highlights, rectangles, and visual whiteout; it does not change existing text objects or securely redact content. Signatures are visible typed, drawn, or uploaded marks, without digital certificates.
- Cloud account integrations, authentication, subscription billing, ads, analytics, and localization are not implemented.
- Scanner uses manual shutter capture with Single/Multi modes and ID framing. Auto Crop estimates a bright document boundary and may need manual adjustment on cluttered or low-contrast images. Auto-capture, shadow removal, integrated OCR, ID front/back composition, book modes, and low-light/blur detection are not implemented.
- Existing PDF operations use the supplied Python service; they are not on-device or available offline. Local images, scans, and PDF creation are offline.
- Organize uses a page-order field instead of a thumbnail drag grid. Split currently exports each selected page separately. Blank-page insertion, range groups, watermark images/tiling, and custom numbering formats are not implemented.
- Compression has no guaranteed target size. Image compression exports JPEG; lossless PNG compression and WebP encoding are not implemented. HEIC is not supported. Animated inputs are treated as still images. Resize is width-based only.
- PDF text creation and watermarking currently use standard Latin fonts. Multilingual fonts, translated UI, and localized RTL flows remain to be implemented. Flutter's native semantics and scalable text are retained; a complete accessibility audit remains.
- Completed outputs save automatically on the device. Browser storage is subject to browser quotas. My files is local storage, not cloud synchronization.
- The client permits 5 files per task, 25 MB per file, 50 MB total. The service limits total pages to 500 and concurrent requests to 2. Premium limits and daily quotas are not implemented.
- Cancellation disconnects the remote request or discards the local result. Work already running in a service thread may complete; background jobs and resumable processing are not implemented.
- Android/iOS scaffolds are included (Android 8+, iOS 15+). iOS compilation requires macOS/Xcode; physical-device camera, sharing, lifecycle, and permission behavior need device testing.

## Mobile service connections

Android defaults to the emulator host address `http://10.0.2.2:8000`; older saved local loopback addresses are migrated automatically. You can also use `adb reverse tcp:8000 tcp:8000` for a USB-connected device using the local service. Debug builds permit cleartext HTTP for local development.

For a physical phone, run the processor with `--host 0.0.0.0` and set the URL to the computer's LAN address, using only a trusted development network. Release builds should use your own HTTPS service. The default loopback address points to the phone itself, so it will not reach your computer.

iOS release configuration intentionally does not bypass App Transport Security. Use HTTPS for a service connection. Camera and photo-library usage descriptions are configured.

## Privacy and production deployment

Every remote tool displays the service destination before the user presses Upload & Process. The provided service parses multipart uploads and processes basic PDF operations in memory. Office conversion and OCR use temporary files that are removed after processing, including failure paths. It does not retain an upload/output store; access logging is disabled by the documented start command. This avoids a retained upload store requiring a deletion timer. Process memory is released by the runtime and is not guaranteed to be securely zeroed.

This service is intended for local development. Before an internet deployment, add authentication, HTTPS termination, per-user rate limits, isolated worker processes with resource/time limits, production monitoring without document/password logging, a signed privacy policy, subscription validation, and compliance review. Do not expose the development service as a public production API. CORS defaults to localhost:8080 and 127.0.0.1:8080; set `ALLOWED_ORIGINS` to an explicit comma-separated list for another trusted frontend.

PDF rewrites can invalidate existing digital signatures. Visible signatures are supported; certificate-based digital signing and legal signing workflows are not implemented. Unlock requires the password for encrypted PDFs and does not crack passwords.

## Verification

```powershell
flutter analyze
flutter test --no-pub
backend/.venv/Scripts/python.exe -m pytest -q backend
flutter build web --release
flutter build apk --debug
```

Tests cover real byte encoding, resize aspect ratio, ZIP batches, image/text PDF creation, corrupt inputs, scanner geometry and grayscale, navigation, active tools, annotation placement and undo/redo, typed signatures, desktop/narrow layouts, PDF merge/order/split/extract/rotation, encryption and incorrect passwords, watermark/numbering/text extraction, compression preservation, rendering/repair, and multipart API requests.

Package API references: [file_picker](https://pub.dev/packages/file_picker), [image_picker](https://pub.dev/packages/image_picker), [pdf](https://pub.dev/packages/pdf), [printing](https://pub.dev/packages/printing), [pypdf](https://pypdf.readthedocs.io/), [pypdfium2](https://pypdfium2.readthedocs.io/).

Camera capture uses the official [Flutter camera plugin](https://pub.dev/packages/camera), with permission error handling and lifecycle cleanup.

Current local verification: 35 Flutter tests, 8 Supabase Edge Function tests, and 29 processing service tests pass; Flutter analysis is clean. The live HTTP smoke test also verifies the local preview, service health, and a valid two-page merge. Web release and Android debug APK builds are supplied. Browser-based visual inspection was unavailable because no browser was connected; physical mobile testing and iOS build validation remain outstanding.

## Glossy 3D tool artwork

The active tool icons are transparent PNGs in `assets/tool_icons_3d/`, generated with built-in ImageGen to match the supplied glossy PDF-to-Excel reference. All 28 tools plus the scanner have distinct artwork. The previous flat assets remain available in `assets/tool_icons/`.

- Full set preview: `output/imagegen/tool-icons-3d/catalog-preview.png`
- Download archive: `output/imagegen/tool-icons-3d.zip`
- Untouched high-resolution originals: `output/imagegen/tool-icons-3d/originals/`
- Exact generation prompts and source provenance: `output/imagegen/source-manifest.json`

`scripts/prepare_3d_icons.py` copies the generated originals and prepares uniform, optimized display PNGs while preserving alpha. It does not generate or repaint artwork. Run it again only while the source files recorded in the manifest are available.

## Performance

Scrolling cards use translucent gradients without per-card background blur; live blur is limited to navigation and app bars. Artwork decoding uses bounded display sizes, and cards isolate painting. For representative performance, use `flutter run --profile` or the release APK; debug mode includes development overhead. Release builds allow HTTP only for the local Android emulator and loopback processor addresses; other processor connections require HTTPS.

Scanner and photo enhancement use matching hero banners. The enhancement banner opens offline on-device AI enhancement with an optional local brightness/contrast/color mode.

The home hero supports horizontal swiping between PDF creation and local photo enhancement, with tappable slide indicators.

Scanner filter taps update the preview immediately using cached, background-rendered thumbnails. Switching to Original restores the source image; export applies the selected filter once at full resolution. Confirming a page opens Scan completed with PDF Save and Share actions, followed by Continue scanning to retain the page in the session.


## Automatic saving and offline AI enhancement

Every completed conversion or AI response saves automatically in **My files**. Confirmed scanner pages are also saved as PDF, and exporting a multipage scan saves its combined PDF. My files supports search, opening, renaming, favorites, deletion, and **Download** in each file menu. PDFs, images, and text have in-app previews; Office documents open in an installed compatible app on Android/iOS. Browser users download Office files to view them.

Android/iOS store the actual output bytes in the app support directory, with a small catalog in preferences. The old 8 MB file limit and 12 MB history eviction are removed. Existing cached files migrate on startup. Files stay until the user deletes them or clears/uninstalls the app. Browser persistence uses browser local storage and is subject to its quota; failed saves leave the result available for download.

Image enhancement now uses a bundled TensorFlow Lite ESRGAN model on Android/iOS. It runs offline without login, an API key, or a GPU server. The basic enhancement option keeps the original resolution. AI enhancement offers 2x/4x export after resizing large source photos to a maximum 512-pixel longest edge, runs in a separate isolate, reports progress, and supports cancellation between tiles. Slow jobs are capped at 90 seconds between inference calls.

Model provenance and notices: [model README](assets/models/README.md). Android inference and cancellation are tested in `integration_test/device_enhancement_test.dart`. The legacy PC Upscayl worker is optional and is not used by mobile enhancement.
