import 'glass.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'models.dart';

class DocumentMarkup extends StatefulWidget {
  final Uint8List bytes;
  final bool signing;
  final List<Map<String, dynamic>> initialOperations;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  const DocumentMarkup({
    super.key,
    required this.bytes,
    required this.signing,
    this.initialOperations = const [],
    required this.onChanged,
  });
  @override
  State<DocumentMarkup> createState() => _DocumentMarkupState();
}

class _DocumentMarkupState extends State<DocumentMarkup> {
  final text = TextEditingController();
  final page = TextEditingController(text: '1');
  final List<Map<String, dynamic>> operations = [];
  final List<Map<String, dynamic>> undone = [];
  final List<List<Offset>> strokes = [];
  Uint8List? preview, signature;
  double ratio = .707,
      pdfWidth = 612,
      boxWidth = .35,
      boxHeight = .1,
      fontSize = 16;
  String kind = 'text', signatureMode = 'Type';
  bool loading = false;
  String? error;
  int ticket = 0, currentPage = 1;
  @override
  void initState() {
    super.initState();
    operations.addAll(
      widget.initialOperations.map((o) => Map<String, dynamic>.from(o)),
    );
    if (widget.signing) {
      kind = 'signature_text';
    }
    load();
  }

  @override
  void dispose() {
    ticket++;
    text.dispose();
    page.dispose();
    super.dispose();
  }

  void publish() => widget.onChanged(
    operations.map((o) => Map<String, dynamic>.from(o)).toList(),
  );
  Future<void> load() async {
    final p = int.tryParse(page.text);
    if (p == null || p < 1 || p > 500) {
      setState(() => error = 'Choose a page between 1 and 500.');
      return;
    }
    final request = ++ticket;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final raster = await Printing.raster(
        widget.bytes,
        pages: [p - 1],
        dpi: 96,
      ).first;
      final bytes = await raster.toPng();
      if (mounted && request == ticket) {
        setState(() {
          preview = bytes;
          ratio = raster.width / raster.height;
          pdfWidth = raster.width * 72 / 96;
          currentPage = p;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted && request == ticket) {
        setState(() {
          loading = false;
          error =
              'Could not preview that page. Check the page number and unlock encrypted PDFs first.';
        });
      }
    }
  }

  void place(Offset offset, Size size) {
    final imageKind = widget.signing && signatureMode != 'Type';
    if ((kind == 'text' || kind == 'signature_text') &&
        !imageKind &&
        text.text.trim().isEmpty) {
      setState(() => error = 'Enter the text or name to place.');
      return;
    }
    if (imageKind && signature == null) {
      setState(
        () => error = 'Use your drawing or upload a signature image first.',
      );
      return;
    }
    final x = (offset.dx / size.width).clamp(0.0, 1 - boxWidth);
    final y = (offset.dy / size.height).clamp(0.0, 1 - boxHeight);
    final operation = <String, dynamic>{
      'page': currentPage,
      'kind': imageKind ? 'signature_image' : kind,
      'x': x,
      'y': y,
      'width': boxWidth,
      'height': boxHeight,
      'text': text.text.trim(),
      'fontSize': fontSize,
      'color': widget.signing ? '#202020' : '#7428F5',
      if (imageKind) 'image': base64Encode(signature!),
    };
    setState(() {
      operations.add(operation);
      undone.clear();
      error = null;
    });
    publish();
  }

  Future<void> useDrawing() async {
    if (!strokes.any((s) => s.length > 1)) {
      setState(() => error = 'Draw your signature first.');
      return;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintSignature(canvas, const Size(600, 200), strokes);
    final picture = recorder.endRecording();
    final image = await picture.toImage(600, 200);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (mounted) {
      setState(() {
        signature = data!.buffer.asUint8List();
        error = null;
      });
    }
  }

  Future<void> uploadSignature() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (selection == null || !mounted) {
      return;
    }
    final bytes = selection.files.single.bytes;
    if (bytes == null || bytes.length > 1500000) {
      setState(() => error = 'Use a PNG or JPG signature under 1.5 MB.');
      return;
    }
    setState(() => signature = bytes);
  }

  void chooseMode(String mode) => setState(() {
    signatureMode = mode;
    signature = null;
  });
  Future<void> scanSignature() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 1500000) {
        setState(() => error = 'Use a signature photo under 1.5 MB.');
        return;
      }
      setState(() {
        signatureMode = 'Scan';
        signature = bytes;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Camera unavailable. Use Draw or Upload instead.',
        );
      }
    }
  }

  Widget toolButton(
    IconData icon,
    String label,
    bool active,
    VoidCallback tap,
  ) => Expanded(
    child: TextButton(
      onPressed: tap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: active ? brandPurple : Colors.grey),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? brandPurple : Colors.grey,
            ),
          ),
        ],
      ),
    ),
  );
  Widget markFrame(Map<String, dynamic> o, Size size, Widget child) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: GestureDetector(
          key: ValueKey('mark-${operations.indexOf(o)}'),
          onPanUpdate: (d) {
            setState(() {
              o['x'] = ((o['x'] as num) + d.delta.dx / size.width).clamp(
                0.0,
                1.0 - (o['width'] as num),
              );
              o['y'] = ((o['y'] as num) + d.delta.dy / size.height).clamp(
                0.0,
                1.0 - (o['height'] as num),
              );
            });
            publish();
          },
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: brandPurple)),
            child: child,
          ),
        ),
      ),
      Positioned(
        left: 0,
        top: 0,
        child: SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            tooltip: 'Delete item',
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: brandPurple,
              foregroundColor: Colors.white,
            ),
            iconSize: 15,
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                operations.remove(o);
                undone.clear();
              });
              publish();
            },
          ),
        ),
      ),
      Positioned(
        right: 0,
        bottom: 0,
        child: GestureDetector(
          key: ValueKey('resize-${operations.indexOf(o)}'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            setState(() {
              o['width'] = ((o['width'] as num) + d.delta.dx / size.width)
                  .clamp(.05, 1.0 - (o['x'] as num));
              o['height'] = ((o['height'] as num) + d.delta.dy / size.height)
                  .clamp(.03, 1.0 - (o['y'] as num));
            });
            publish();
          },
          child: const CircleAvatar(
            radius: 12,
            backgroundColor: brandPurple,
            child: Icon(Icons.open_in_full, size: 14, color: Colors.white),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.signing ? 'Place your signature' : 'Annotate your PDF',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      if (loading) const LinearProgressIndicator(),
      if (preview != null)
        SizedBox(
          height: 440,
          child: Center(
            child: AspectRatio(
              aspectRatio: ratio,
              child: LayoutBuilder(
                builder: (_, c) => GestureDetector(
                  onTapUp: loading
                      ? null
                      : (d) => place(
                          d.localPosition,
                          Size(c.maxWidth, c.maxHeight),
                        ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(preview!, fit: BoxFit.fill),
                      ),
                      for (final o in operations.where(
                        (o) => o['page'] == currentPage,
                      ))
                        Positioned(
                          left: (o['x'] as num) * c.maxWidth,
                          top: (o['y'] as num) * c.maxHeight,
                          width: (o['width'] as num) * c.maxWidth,
                          height: (o['height'] as num) * c.maxHeight,
                          child: markFrame(
                            o,
                            Size(c.maxWidth, c.maxHeight),
                            o['kind'] == 'signature_image'
                                ? Image.memory(
                                    base64Decode(o['image']),
                                    fit: BoxFit.contain,
                                  )
                                : o['kind'] == 'text' ||
                                      o['kind'] == 'signature_text'
                                ? Text(
                                    o['text'],
                                    style: TextStyle(
                                      color: o['kind'] == 'signature_text'
                                          ? Colors.black
                                          : brandPurple,
                                      fontStyle: o['kind'] == 'signature_text'
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                      fontSize:
                                          (o['fontSize'] as num) *
                                          c.maxWidth /
                                          pdfWidth,
                                    ),
                                    overflow: TextOverflow.clip,
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: o['kind'] == 'highlight'
                                          ? Colors.yellow.withValues(alpha: .35)
                                          : o['kind'] == 'whiteout'
                                          ? Colors.white
                                          : null,
                                      border: o['kind'] == 'rectangle'
                                          ? Border.all(
                                              color: brandPurple,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 16),
      GlassSurface(
        radius: 22,
        child: Row(
          children: widget.signing
              ? [
                  toolButton(
                    Icons.text_fields,
                    'Text',
                    signatureMode == 'Type',
                    () => chooseMode('Type'),
                  ),
                  toolButton(
                    Icons.draw_outlined,
                    'Draw',
                    signatureMode == 'Draw',
                    () => chooseMode('Draw'),
                  ),
                  toolButton(
                    Icons.document_scanner_outlined,
                    'Scan',
                    signatureMode == 'Scan',
                    scanSignature,
                  ),
                  toolButton(
                    Icons.image_outlined,
                    'Upload',
                    signatureMode == 'Upload',
                    () => chooseMode('Upload'),
                  ),
                ]
              : [
                  toolButton(
                    Icons.text_fields,
                    'Text',
                    kind == 'text',
                    () => setState(() => kind = 'text'),
                  ),
                  toolButton(
                    Icons.highlight_outlined,
                    'Highlight',
                    kind == 'highlight',
                    () => setState(() => kind = 'highlight'),
                  ),
                  toolButton(
                    Icons.format_color_fill_outlined,
                    'Cover',
                    kind == 'whiteout',
                    () => setState(() => kind = 'whiteout'),
                  ),
                  toolButton(
                    Icons.crop_square,
                    'Box',
                    kind == 'rectangle',
                    () => setState(() => kind = 'rectangle'),
                  ),
                ],
        ),
      ),
      const SizedBox(height: 12),
      ExpansionTile(
        initiallyExpanded: true,
        title: const Text('Tool options'),
        children: [
          if (widget.signing) ...[
            if (signatureMode == 'Type')
              TextField(
                controller: text,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  helperText:
                      'Adds a visible signature; no digital certificate.',
                ),
              ),
            if (signatureMode == 'Draw') ...[
              Container(
                height: 140,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: lavenderBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (_, c) => GestureDetector(
                    onPanStart: (d) => setState(
                      () => strokes.add([
                        Offset(
                          d.localPosition.dx / c.maxWidth,
                          d.localPosition.dy / c.maxHeight,
                        ),
                      ]),
                    ),
                    onPanUpdate: (d) => setState(() {
                      strokes.last.add(
                        Offset(
                          (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0),
                          (d.localPosition.dy / c.maxHeight).clamp(0.0, 1.0),
                        ),
                      );
                      signature = null;
                    }),
                    child: CustomPaint(
                      painter: SignaturePainter(strokes),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      strokes.clear();
                      signature = null;
                    }),
                    child: const Text('Clear drawing'),
                  ),
                  OutlinedButton(
                    onPressed: useDrawing,
                    child: const Text('Use drawing'),
                  ),
                ],
              ),
            ],
            if (signatureMode == 'Upload')
              OutlinedButton.icon(
                onPressed: uploadSignature,
                icon: const Icon(Icons.upload),
                label: const Text('Upload signature PNG/JPG'),
              ),
            if (signature != null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Signature ready. Tap the page to place it.',
                  style: TextStyle(color: brandPurple),
                ),
              ),
          ] else ...[
            DropdownButtonFormField<String>(
              key: ValueKey(kind),
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Annotation'),
              items: const [
                DropdownMenuItem(value: 'text', child: Text('Add text')),
                DropdownMenuItem(
                  value: 'highlight',
                  child: Text('Highlight area'),
                ),
                DropdownMenuItem(
                  value: 'whiteout',
                  child: Text('Cover area with white'),
                ),
                DropdownMenuItem(
                  value: 'rectangle',
                  child: Text('Draw rectangle'),
                ),
              ],
              onChanged: (v) => setState(() => kind = v!),
            ),
            const SizedBox(height: 12),
            if (kind == 'text')
              TextField(
                controller: text,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Text to add'),
              ),
            if (kind == 'whiteout')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Whiteout is a visual cover. Underlying text remains extractable; use a redaction tool for sensitive information.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Text('Size: ${(boxWidth * 100).round()}% of page width'),
          Slider(
            value: boxWidth,
            min: .1,
            max: .7,
            onChanged: (v) => setState(() => boxWidth = v),
          ),
          Text('Area height: ${(boxHeight * 100).round()}% of page'),
          Slider(
            value: boxHeight,
            min: .03,
            max: .3,
            onChanged: (v) => setState(() => boxHeight = v),
          ),
          if (kind == 'text' || signatureMode == 'Type') ...[
            Text('Text size: ${fontSize.round()} pt'),
            Slider(
              value: fontSize,
              min: 8,
              max: 48,
              divisions: 40,
              onChanged: (v) => setState(() => fontSize = v),
            ),
          ],
        ],
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: page,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Page number'),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: loading ? null : load,
            child: const Text('Load page'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Tap to place. Drag an item to move it; drag its corner to resize.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: operations.isEmpty
                ? null
                : () {
                    setState(() => undone.add(operations.removeLast()));
                    publish();
                  },
            icon: const Icon(Icons.undo),
            label: const Text('Undo'),
          ),
          TextButton.icon(
            onPressed: undone.isEmpty
                ? null
                : () {
                    setState(() => operations.add(undone.removeLast()));
                    publish();
                  },
            icon: const Icon(Icons.redo),
            label: const Text('Redo'),
          ),
          Text('${operations.length} items placed'),
        ],
      ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}

void paintSignature(Canvas canvas, Size size, List<List<Offset>> strokes) {
  final paint = Paint()
    ..color = Colors.black
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  for (final stroke in strokes) {
    if (stroke.isEmpty) {
      continue;
    }
    final path = Path()
      ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
    for (final p in stroke.skip(1)) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    canvas.drawPath(path, paint);
  }
}

class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  SignaturePainter(this.strokes);
  @override
  void paint(Canvas canvas, Size size) => paintSignature(canvas, size, strokes);
  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}

class DocumentEditorScreen extends StatefulWidget {
  final DocFile file;
  final bool signing;
  final List<Map<String, dynamic>> operations;
  const DocumentEditorScreen({
    super.key,
    required this.file,
    required this.signing,
    required this.operations,
  });
  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  late List<Map<String, dynamic>> draft = widget.operations
      .map((o) => Map<String, dynamic>.from(o))
      .toList();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.file.name, style: const TextStyle(fontSize: 15)),
      actions: [
        IconButton(
          tooltip: 'Save changes',
          icon: const Icon(Icons.save_outlined),
          onPressed: () => Navigator.pop(context, draft),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: DocumentMarkup(
            bytes: widget.file.bytes,
            signing: widget.signing,
            initialOperations: draft,
            onChanged: (value) => draft = value,
          ),
        ),
      ),
    ),
  );
}
