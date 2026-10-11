# PRD: All-in-One PDF, Image & Scanner App

**Working name:** ALI - Docs (placeholder) **Platforms:** Android, iOS, Web (responsive) **Document status:** Draft v1.0 **Reference product:** iLovePDF

---

## 1. Overview

### 1.1 Problem

People constantly need to merge, split, compress, convert, sign, or scan documents. Existing solutions are either scattered across many apps, hidden behind aggressive paywalls, or require uploading sensitive files to unknown servers.

### 1.2 Product Vision

A single, fast, easy app where anyone can handle every PDF task, every common image task, and document scanning, all in one place, with a clean interface and strong privacy.

### 1.3 Goals

- Offer 25+ PDF tools in one app, covering everything users expect from iLovePDF.
- Add a dedicated Image Tools section and a dedicated Scanner tab.
- Make any common task completable in 3 taps or fewer.
- Process files quickly and delete uploaded files automatically.
- Build a sustainable freemium business.

### 1.4 Non-Goals (v1)

- Real-time multi-user collaboration on documents.
- Cloud storage product of its own (we integrate with existing ones).
- Advanced desktop publishing or full PDF layout redesign.
- Video or audio tools.

---

## 2. Target Users

| Persona | Description | Key Needs |
| --- | --- | --- |
| Student | Submits assignments, scans notes, merges chapters | Free, fast, scan + compress + merge |
| Office professional | Handles contracts, invoices, reports | Convert Office files, sign, protect, watermark |
| Freelancer / small business | Sends proposals, signs agreements | Sign PDF, compress for email, page numbers |
| General user | Occasional tasks (ID copy, forms) | Simple scanner, image to PDF, resize image |

---

## 3. App Structure and Navigation

Bottom navigation with **four tabs**:

1. **Home / PDF Tools:** all PDF tools, grouped by category.
2. **Image Tools:** separate section for image utilities.
3. **Scanner:** camera-based document scanning.
4. **My Files:** recent files, history, and saved outputs (plus Settings via profile icon).

**Global elements:** search bar for tools, recent files strip, favorites (pin tools), file picker (device, Google Drive, Dropbox, OneDrive), and a share/save sheet after each task.

---

## 4. Feature Requirements: PDF Tools

Priority key: **P0** = must have at launch, **P1** = launch if possible, **P2** = post-launch.

### 4.1 Organize PDF

| # | Tool | Description | Key Requirements | Priority |
| --- | --- | --- | --- | --- |
| 1 | **Merge PDF** | Combine multiple PDFs into one | Select multiple files, drag to reorder, preview thumbnails, add files from cloud | P0 |
| 2 | **Split PDF** | Divide a PDF into several files | Split by page range, extract every N pages, split into single pages, visual page selector | P0 |
| 3 | **Organize PDF** | Reorder, delete, rotate, and insert pages | Thumbnail grid, drag and drop, multi-select, add blank page | P0 |
| 4 | **Rotate PDF** | Rotate pages 90/180/270 degrees | Rotate all or selected pages, live preview | P0 |
| 5 | **Extract Pages** | Pull selected pages into a new PDF | Page selector and range input | P1 |

### 4.2 Optimize PDF

| # | Tool | Description | Key Requirements | Priority |
| --- | --- | --- | --- | --- |
| 6 | **Compress PDF** | Reduce file size | Three levels (Low, Recommended, Extreme), show before/after size and % saved, optional target size | P0 |
| 7 | **Repair PDF** | Recover corrupted PDFs | Attempt rebuild of structure, report recovered pages, clear failure message | P1 |
| 8 | **OCR PDF** | Make scanned PDFs searchable and selectable | Multi-language OCR, output searchable PDF, language auto-detect | P0 |

### 4.3 Convert TO PDF

| # | Tool | Description | Key Requirements | Priority |
| --- | --- | --- | --- | --- |
| 9 | **Word to PDF** | .doc/.docx to PDF | Preserve fonts, tables, images, layout | P0 |
| 10 | **PowerPoint to PDF** | .ppt/.pptx to PDF | Preserve slides, options for notes or handout layout | P0 |
| 11 | **Excel to PDF** | .xls/.xlsx to PDF | Fit to page width, choose sheets, orientation | P0 |
| 12 | **Image to PDF** | JPG, PNG and more to PDF | Multi-image, reorder, page size (A4, Letter, fit), margins, orientation | P0 |
| 13 | **Create PDF** | Create a new PDF from text or blank | Simple text editor with basic formatting, templates (letter, notes) | P1 |

### 4.4 Convert FROM PDF

| # | Tool | Description | Key Requirements | Priority |
| --- | --- | --- | --- | --- |
| 14 | **PDF to Word** | PDF to editable .docx | Keep layout, tables, images; use OCR for scanned files | P0 |
| 15 | **PDF to PowerPoint** | PDF to .pptx | One slide per page, editable text where possible | P0 |
| 16 | **PDF to Excel** | PDF to .xlsx | Detect and extract tables to cells, multi-table support | P0 |
| 17 | **PDF to JPG** | PDF pages to images | Choose pages or all, quality/DPI options, ZIP output for multi-page | P0 |
| 18 | **Extract Text (PDF to TXT)** | Pull all text into .txt | Use OCR fallback for scans, copy to clipboard | P0 |

### 4.5 Edit and Enhance PDF

| # | Tool | Description | Key Requirements | Priority |
| --- | --- | --- | --- | --- |
| 19 | **Edit PDF** | Modify PDF content | Add text, shapes, highlights, freehand drawing, images, whiteout; edit font/size/color; undo/redo | P0 |
| 20 | **Page Numbers** | Add numbering | Position (6 options), format (1, 1/10, Page 1), start number, page range, font/size | P0 |
| 21 | **Watermark** | Add text or image watermark | Text or image, opacity, rotation, size, position, tile mode, page range | P0 |
| 22 | **Sign PDF** | Add signature | Draw, type, or upload signature; save signatures; place, resize, date stamp; multiple signatures | P0 |

### 4.6 PDF Security

| # | Tool | Description | Key Requirements | Priority |
| --- | --- | --- | --- | --- |
| 23 | **Protect PDF** | Encrypt with password | AES-256, set open password and optional permissions (print, copy, edit) | P0 |
| 24 | **Unlock PDF** | Remove password/restrictions | Requires user to provide password where an open password exists; remove edit/print restrictions; legal notice that users must own the rights to the file | P0 |

### 4.7 Common PDF Tool Behavior

Every tool follows the same four-step flow:

1. **Select file(s):** device, cloud, or recent files.
2. **Configure options:** minimal, sensible defaults.
3. **Process:** progress indicator, cancel option, estimated time.
4. **Result:** preview, save, share, open in another tool ("Next step" suggestions, e.g. after Merge suggest Compress or Page Numbers).

---

## 5. Feature Requirements: Image Tools (Separate Section)

| # | Tool | Description | Key Requirements | Priority |
| --- | --- | --- | --- | --- |
| 1 | **Compress Image** | Reduce image file size | Batch support, quality slider, target size (e.g. under 100 KB), show before/after size, supports JPG, PNG, WebP | P0 |
| 2 | **Convert to JPG** | Convert other formats to JPG | Input: PNG, WebP, HEIC, GIF, BMP, TIFF; batch; quality setting; background color for transparent PNGs | P0 |
| 3 | **Convert from JPG** | Convert JPG to other formats | Output: PNG, WebP, GIF, BMP, TIFF; batch | P0 |
| 4 | **Resize Image** | Change image dimensions | By pixels or percentage; keep aspect ratio lock; presets (social media, passport, ID sizes); batch | P0 |

**Common image behavior:** batch select up to 20 images (free: 5), side-by-side preview, ZIP download for batches, EXIF privacy option (strip metadata).

**Future image tools (P2):** crop, rotate/flip, remove background, photo editor, blur face/sensitive areas, upscale.

---

## 6. Feature Requirements: Scanner Tab

A dedicated tab for turning the phone camera into a document scanner.

### 6.1 Core Capabilities

| Feature | Requirements | Priority |
| --- | --- | --- |
| **Camera capture** | Live camera view, auto-capture when document is steady, manual shutter, flash toggle, grid overlay | P0 |
| **Auto edge detection** | Detect document borders in real time; manual corner adjustment after capture | P0 |
| **Perspective correction** | Flatten skewed documents to a clean rectangle | P0 |
| **Image enhancement filters** | Original, Auto, Magic Color, Black & White, Grayscale, remove shadows | P0 |
| **Multi-page scanning** | Add unlimited pages in one session, reorder, delete, retake single page | P0 |
| **Import from gallery** | Pick existing photos to scan | P0 |
| **Scan modes** | Document, ID Card (front and back on one page), Book (two-page spread split), Whiteboard, Receipt | P1 |
| **Built-in OCR** | Extract text from scans, searchable PDF output, copy text | P0 |
| **Export** | Save as PDF or JPG; choose page size and quality; share or send to other tools (Compress, Sign, Watermark) | P0 |
| **Scan library** | Folders, rename, search by name or OCR text, delete, favorites | P1 |
| **Quick actions after scan** | Sign, Add watermark, Protect, Compress, Convert | P1 |

### 6.2 Scanner UX Requirements

- Camera ready in under 1.5 seconds after tapping the tab.
- Works fully offline (scanning, filters, PDF export).
- Low-light guidance ("Turn on flash") and blur warning.

---

## 7. Monetization

**Model:** Freemium with subscription.

|  | Free | Premium |
| --- | --- | --- |
| Basic tools (merge, split, rotate, image tools) | Yes, with daily limit | Unlimited |
| Max file size | 25 MB | 500 MB+ |
| Files per task | Limited (e.g. 5) | Large batches |
| OCR | Few pages per day | Unlimited |
| Advanced (Edit, PDF to Word/Excel/PPT) | Limited daily uses | Unlimited |
| Ads | Banner/interstitial between tasks | No ads |
| Watermark on output | Never (builds trust) | Never |
| Cloud sync and history | 7 days | 30+ days |

**Plans:** Weekly, Monthly, Yearly (best value), with free trial. Add a team/business plan in a later phase.

---

## 8. Non-Functional Requirements

### 8.1 Performance

- Simple tools (merge, split, rotate) complete in under 5 seconds for files under 10 MB.
- Compression and conversion complete in under 30 seconds for files under 25 MB.
- App cold start under 2.5 seconds.

### 8.2 Privacy and Security

- On-device processing wherever feasible (rotate, merge, split, page numbers, scanner, image tools).
- Server processing for heavy conversions, over TLS 1.2+ encryption.
- Uploaded files are **automatically deleted within 1 hour** (configurable shorter); no human access to user files.
- Clear privacy policy; no use of user documents for training or advertising.
- Passwords never stored or logged.
- Compliance: GDPR, CCPA.

### 8.3 Reliability

- Conversion success rate of 98% or higher.
- Graceful failure messages with retry; background processing continues if the app is minimized.

### 8.4 Compatibility

- Android 8.0+; iOS 15+; modern browsers for web.
- Supports files: PDF, DOC/DOCX, PPT/PPTX, XLS/XLSX, JPG, PNG, WebP, HEIC, GIF, BMP, TIFF, TXT.

### 8.5 Accessibility and Localization

- Screen reader support, scalable fonts, high contrast.
- RTL support (Arabic, Urdu) and launch languages: English, Arabic, Hindi, Spanish, French, Portuguese, Indonesian, Turkish.

---

## 9. Technical Considerations

| Area | Suggested Approach |
| --- | --- |
| **Client** | Flutter or React Native for cross-platform; native camera module for scanner |
| **PDF engine (on-device)** | PDFium / MuPDF / PDFBox-based libraries for merge, split, rotate, render |
| **Document scanning** | OpenCV or ML Kit Document Scanner for edge detection and perspective correction |
| **OCR** | Tesseract (on-device, basic) plus cloud OCR (Google Vision or similar) for higher accuracy |
| **Office conversions** | Server-side LibreOffice headless or commercial SDK (Aspose, PSPDFKit, Apryse) for high fidelity |
| **PDF to Word/Excel/PPT** | Commercial SDK recommended for layout and table accuracy |
| **Backend** | Stateless microservices with job queue (e.g. SQS/RabbitMQ), autoscaling workers, object storage with TTL |
| **Auth** | Email, Google, Apple sign-in; guest mode for basic use |
| **Analytics** | Funnel per tool, error rates, conversion times |

---

## 10. Success Metrics

| Metric | Target (6 months post-launch) |
| --- | --- |
| Monthly active users | 500,000 |
| Day-1 / Day-30 retention | 40% / 12% |
| Task completion rate (start to saved result) | 85% or higher |
| Average tasks per active user per week | 3+ |
| Free to paid conversion | 3 to 5% |
| App store rating | 4.5 or higher |
| Conversion failure rate | Under 2% |

---

## 11. Release Plan

| Phase | Scope | Timeline |
| --- | --- | --- |
| **MVP (Phase 1)** | Merge, Split, Compress, Rotate, Organize, Image to PDF, PDF to JPG, Page Numbers, Watermark, Protect, Unlock; Image tools (all 4); Scanner basic (capture, crop, filters, export PDF) | Months 1 to 3 |
| **Phase 2** | Office to PDF (Word, PPT, Excel), PDF to Word/PPT/Excel, Extract Text, Sign PDF, OCR PDF, Scanner OCR and multi-mode | Months 4 to 6 |
| **Phase 3** | Edit PDF, Repair PDF, Create PDF, cloud integrations, scan library with search, web version | Months 7 to 9 |
| **Phase 4** | Batch processing, team plans, AI features (summarize, chat with PDF, translate), more image tools | Months 10+ |

---

## 12. Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Poor Office to PDF / PDF to Word fidelity | Bad reviews, churn | Use a commercial SDK; extensive test corpus |
| High server cost from heavy conversions | Margin pressure | On-device processing where possible; daily limits for free users; autoscaling and caching |
| Privacy concerns about uploading documents | Trust loss | Auto-delete, clear messaging, on-device default, no ads on result screens with documents |
| Strong competitors (iLovePDF, Adobe, Smallpdf) | Slow growth | Differentiate with scanner + image tools in one app, better UX, regional language support |
| Unlock PDF misuse | Legal exposure | Require password for encrypted files; terms of use; no password cracking |
| App store policy on subscriptions and ads | Rejection | Follow store billing guidelines; transparent trial terms |

---

## 13. Open Questions

1. Should the app work with a login from day one, or allow guest usage?
2. Is a web version required at launch, or app first?
3. Which regions are the primary launch markets (affects languages and pricing)?
4. Will AI features (summarize, chat with PDF) be part of the v1 positioning?
5. Build vs. buy for conversion engine (own LibreOffice stack vs. commercial SDK)?

---

## 14. Appendix: Complete Tool Checklist

**PDF Tools (24):** Merge, Split, Compress, Repair, OCR, Organize, Rotate, Extract Pages, Word to PDF, PowerPoint to PDF, Excel to PDF, Image to PDF, Create PDF, PDF to Word, PDF to PowerPoint, PDF to Excel, PDF to JPG, Extract Text (TXT), Edit PDF, Page Numbers, Watermark, Sign PDF, Protect PDF, Unlock PDF.

**Image Tools (4):** Compress Image, Convert to JPG, Convert from JPG, Resize Image.

**Scanner (separate tab):** Document scan, edge detection, filters, multi-page, OCR, export to PDF/JPG, scan library.
