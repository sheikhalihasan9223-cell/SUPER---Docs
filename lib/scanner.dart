import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'workspace_banner.dart';
import 'scan_camera.dart';
import 'glass.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'processor.dart';
import 'store.dart';
import 'workflow.dart';

class ScannerScreen extends StatefulWidget {
  final AppStore store;
  const ScannerScreen({super.key, required this.store});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final List<DocFile> pages = [];
  bool busy = false;
  String? error;
  Future<void> capture(ImageSource source, {String? card}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final List<Uint8List> captured;
      if (source == ImageSource.camera) {
        final result = await Navigator.push<List<Uint8List>>(
          context,
          MaterialPageRoute(
            builder: (_) => ScanCamera(
              initialCard: card,
              edit: (bytes) => Navigator.push<Uint8List>(
                context,
                MaterialPageRoute(
                  builder: (_) => ScanEditor(bytes: bytes, store: widget.store),
                ),
              ),
            ),
          ),
        );
        captured = result ?? [];
      } else {
        final photo = await ImagePicker().pickImage(
          source: source,
          maxWidth: 2400,
          imageQuality: 95,
        );
        if (photo == null || !mounted) return;
        final bytes = await photo.readAsBytes();
        if (!mounted) return;
        final adjusted = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(
            builder: (_) => ScanEditor(bytes: bytes, store: widget.store),
          ),
        );
        captured = adjusted == null ? [] : [adjusted];
      }
      if (!mounted) return;
      setState(() {
        for (final adjusted in captured) {
          pages.add(
            DocFile(
              id: '${DateTime.now().microsecondsSinceEpoch}-${pages.length}',
              name: 'Page ${pages.length + 1}.jpg',
              bytes: adjusted,
              created: DateTime.now(),
              tool: 'Scanner',
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = cleanError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> export() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await compute(localWorker, {
        'id': 'scan',
        'files': pages.map((f) => {'name': f.name, 'bytes': f.bytes}).toList(),
        'options': {'pageSize': 'A4'},
      });
      if (!mounted) {
        return;
      }
      final f = DocFile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: 'Scan-${DateTime.now().millisecondsSinceEpoch}.pdf',
        bytes: result.bytes,
        created: DateTime.now(),
        tool: 'Scanner',
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(file: f, store: widget.store),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = cleanError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Document scanner',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Clear scans. Organized documents.',
        style: TextStyle(color: Colors.grey, height: 1.5),
      ),
      const SizedBox(height: 24),
      WorkspaceBanner(
        images: false,
        heading: 'Paper to PDF,\nin seconds',
        eyebrow: 'SCAN WORKSPACE',
        caption: 'Capture, crop and enhance.\nYour documents, ready to share.',
        actionLabel: 'Capture a page',
        assetPath: 'assets/tool_icons_3d/scanner.png',
        onStart: () {
          if (!busy) capture(ImageSource.camera);
        },
      ),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: busy ? null : () => capture(ImageSource.gallery),
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Import a photo'),
      ),
      const SizedBox(height: 26),
      const Text(
        'Scan essentials',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      const Text(
        'Choose a guide for your document.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          for (final entry in [
            ('Passport', 'Scan passport'),
            ('ID Card', 'Scan ID card'),
            ('Bank card', 'Scan bank card'),
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: busy
                        ? null
                        : () => capture(ImageSource.camera, card: entry.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 4,
                      ),
                      child: Column(
                        children: [
                          ScanModeArtwork(kind: entry.$1),
                          const SizedBox(height: 12),
                          Text(
                            entry.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      if (busy)
        const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error!, style: const TextStyle(color: brandPurple)),
        ),
      if (pages.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          '${pages.length} pages in this scan',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < pages.length; i++)
          GlassCard(
            child: ListTile(
              leading: Image.memory(
                pages[i].bytes,
                width: 42,
                height: 56,
                fit: BoxFit.cover,
              ),
              title: Text('Page ${i + 1}'),
              subtitle: Text(fileSize(pages[i].bytes.length)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Move page up',
                    onPressed: busy || i == 0
                        ? null
                        : () => setState(() {
                            final p = pages.removeAt(i);
                            pages.insert(i - 1, p);
                          }),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Edit page',
                    onPressed: busy
                        ? null
                        : () async {
                            final adjusted = await Navigator.push<Uint8List>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScanEditor(
                                  bytes: pages[i].bytes,
                                  store: widget.store,
                                ),
                              ),
                            );
                            if (adjusted != null && mounted) {
                              setState(
                                () => pages[i] = DocFile(
                                  id: pages[i].id,
                                  name: pages[i].name,
                                  bytes: adjusted,
                                  created: pages[i].created,
                                  tool: 'Scanner',
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.crop),
                  ),
                  IconButton(
                    tooltip: 'Remove page',
                    onPressed: busy
                        ? null
                        : () => setState(() => pages.removeAt(i)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : export,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Create PDF'),
        ),
        TextButton(
          onPressed: busy ? null : () => setState(() => pages.clear()),
          child: const Text('Start a new scan'),
        ),
      ],
      const SizedBox(height: 24),
    ],
  );
}

class ScanEditor extends StatefulWidget {
  final Uint8List bytes;
  final AppStore? store;
  const ScanEditor({super.key, required this.bytes, this.store});
  @override
  State<ScanEditor> createState() => _ScanEditorState();
}

class _ScanEditorState extends State<ScanEditor> {
  List<Offset> points = [
    const Offset(.06, .06),
    const Offset(.94, .06),
    const Offset(.94, .94),
    const Offset(.06, .94),
  ];
  String filter = 'Original';
  bool busy = false;
  String? error;
  Uint8List? preview, filteredPreview;
  final Map<String, Uint8List> filterCache = {};
  int sourceVersion = 0;
  bool renderingFilter = false;
  double ratio = .75;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    sourceVersion++;
    super.dispose();
  }

  void selectFilter(String value) {
    setState(() {
      filter = value;
      filteredPreview = value == 'Original'
          ? preview
          : filterCache[value] ?? filteredPreview;
      error = null;
    });
    renderFilters();
  }

  Future<void> renderFilters() async {
    if (renderingFilter || preview == null) return;
    setState(() => renderingFilter = true);
    try {
      while (mounted &&
          preview != null &&
          filter != 'Original' &&
          !filterCache.containsKey(filter)) {
        final selected = filter, version = sourceVersion;
        final rendered = await compute(scanFilterPreview, {
          'bytes': preview!,
          'filter': selected,
        });
        if (!mounted) return;
        if (version != sourceVersion) continue;
        filterCache[selected] = rendered;
        if (filter == selected) setState(() => filteredPreview = rendered);
      }
    } catch (e) {
      if (mounted) setState(() => error = cleanError(e));
    } finally {
      if (mounted) setState(() => renderingFilter = false);
    }
  }

  void sourceChanged() {
    sourceVersion++;
    filterCache.clear();
    filteredPreview = preview;
  }

  Future<void> load() async {
    try {
      final data = await compute(normalizeScan, widget.bytes);
      if (mounted) {
        setState(() {
          preview = data['bytes'] as Uint8List;
          ratio = data['ratio'] as double;
          sourceChanged();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = cleanError(e));
      }
    }
  }

  Future<void> apply() async {
    setState(() => busy = true);
    try {
      final result = await compute(rectifyScan, {
        'bytes': preview,
        'filter': filter,
        'points': points.map((p) => [p.dx, p.dy]).toList(),
      });
      if (!mounted) return;
      final pdf = await compute(localWorker, {
        'id': 'scan',
        'files': [
          {'name': 'scan.jpg', 'bytes': result},
        ],
        'options': {'pageSize': 'A4'},
      });
      if (!mounted) return;
      await widget.store?.save(
        DocFile(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: 'Scan-${DateTime.now().millisecondsSinceEpoch}.pdf',
          bytes: pdf.bytes,
          created: DateTime.now(),
          tool: 'Scanner',
        ),
      );
      if (!mounted) return;
      final keep = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ScanSuccessPage(
            image: result,
            pdf: pdf.bytes,
            saved: widget.store != null,
          ),
        ),
      );
      if (!mounted) return;
      if (keep == true) {
        Navigator.pop(context, result);
      } else {
        setState(() => busy = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = cleanError(e);
          busy = false;
        });
      }
    }
  }

  Future<void> rotate() async {
    if (preview == null || busy) return;
    setState(() => busy = true);
    final result = await compute(rotateScan, preview!);
    if (!mounted) return;
    setState(() {
      preview = result['bytes'] as Uint8List;
      ratio = result['ratio'] as double;
      points = points.map((p) => Offset(1 - p.dy, p.dx)).toList();
      points = [points[3], points[0], points[1], points[2]];
      busy = false;
      sourceChanged();
    });
    selectFilter(filter);
  }

  Future<void> replace() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
    );
    if (photo == null || !mounted) return;
    final result = await compute(normalizeScan, await photo.readAsBytes());
    if (!mounted) return;
    setState(() {
      preview = result['bytes'] as Uint8List;
      ratio = result['ratio'] as double;
      points = fullPage();
      error = null;
      sourceChanged();
    });
    selectFilter(filter);
  }

  Future<void> autoCrop() async {
    if (preview == null || busy) return;
    setState(() => busy = true);
    final found = await compute(detectScanCorners, preview!);
    if (!mounted) return;
    setState(() {
      points = found.map((p) => Offset(p[0], p[1])).toList();
      busy = false;
    });
  }

  List<Offset> fullPage() => [
    Offset.zero,
    const Offset(1, 0),
    const Offset(1, 1),
    const Offset(0, 1),
  ];
  Widget action(IconData icon, String label, VoidCallback callback) => Expanded(
    child: TextButton(
      onPressed: busy || preview == null ? null : callback,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark(),
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Crop'),
        actions: [
          IconButton(
            tooltip: 'Discard page',
            icon: const Icon(Icons.delete_outline),
            onPressed: busy ? null : () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: preview == null
                  ? const Center(
                      child: CircularProgressIndicator(color: scanBlue),
                    )
                  : Center(
                      child: AspectRatio(
                        aspectRatio: ratio,
                        child: LayoutBuilder(
                          builder: (_, c) => Stack(
                            children: [
                              Positioned.fill(
                                child: Image.memory(
                                  filteredPreview ?? preview!,
                                  key: const ValueKey('scan-filter-preview'),
                                  fit: BoxFit.fill,
                                  gaplessPlayback: true,
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: CornerPainter(points),
                                  ),
                                ),
                              ),
                              for (var i = 0; i < 8; i++)
                                Positioned(
                                  left:
                                      (i < 4
                                              ? points[i]
                                              : Offset.lerp(
                                                  points[i - 4],
                                                  points[(i - 3) % 4],
                                                  .5,
                                                )!)
                                          .dx *
                                      (c.maxWidth - 28),
                                  top:
                                      (i < 4
                                              ? points[i]
                                              : Offset.lerp(
                                                  points[i - 4],
                                                  points[(i - 3) % 4],
                                                  .5,
                                                )!)
                                          .dy *
                                      (c.maxHeight - 28),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanUpdate: busy
                                        ? null
                                        : (d) => setState(() {
                                            final indices = i < 4
                                                ? [i]
                                                : [i - 4, (i - 3) % 4];
                                            for (final index in indices) {
                                              points[index] = Offset(
                                                (points[index].dx +
                                                        d.delta.dx / c.maxWidth)
                                                    .clamp(0.0, 1.0),
                                                (points[index].dy +
                                                        d.delta.dy /
                                                            c.maxHeight)
                                                    .clamp(0.0, 1.0),
                                              );
                                            }
                                          }),
                                    child: Semantics(
                                      label: i < 4
                                          ? 'Document corner ${i + 1}, drag to adjust'
                                          : 'Document edge ${i - 3}, drag to adjust',
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: scanBlue,
                                            width: 3,
                                          ),
                                        ),
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
          if (renderingFilter)
            const LinearProgressIndicator(color: scanBlue, minHeight: 2),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  [
                        'Original',
                        'Auto',
                        'Magic Color',
                        'Black & White',
                        'Grayscale',
                      ]
                      .map(
                        (value) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(value),
                            selected: filter == value,
                            onSelected: busy
                                ? null
                                : (_) => selectFilter(value),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Row(
                children: [
                  action(Icons.rotate_90_degrees_ccw, 'Rotate', rotate),
                  action(Icons.photo_library_outlined, 'Replace', replace),
                  action(
                    Icons.crop_free,
                    'No Crop',
                    () => setState(() => points = fullPage()),
                  ),
                  action(Icons.crop, 'Auto Crop', autoCrop),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: scanBlue,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      onPressed: busy || preview == null ? null : apply,
                      child: busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Map<String, dynamic> normalizeScan(Uint8List bytes) {
  var image = decodeDocumentImage(bytes);
  if (image == null) {
    throw const FormatException('Cannot read this photo. Try JPG or PNG.');
  }
  image = img.bakeOrientation(image);
  if (image.width > 2400) {
    image = img.copyResize(image, width: 2400);
  }
  return {
    'bytes': Uint8List.fromList(img.encodeJpg(image, quality: 95)),
    'ratio': image.width / image.height,
  };
}

Uint8List rectifyScan(Map<String, dynamic> data) {
  final image = img.decodeImage(data['bytes'])!;
  final p = (data['points'] as List)
      .map(
        (v) => img.Point(
          (v[0] as double) * (image.width - 1),
          (v[1] as double) * (image.height - 1),
        ),
      )
      .toList();
  double distance(img.Point a, img.Point b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  // Reject crossed corners and near-empty quadrilaterals.
  final cross = <double>[];
  for (var i = 0; i < 4; i++) {
    final a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4];
    cross.add(
      ((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)).toDouble(),
    );
  }
  if (cross.any((v) => v <= 0)) {
    throw const FormatException(
      'Keep the corners in clockwise order without crossing the edges.',
    );
  }
  final w = math.max(distance(p[0], p[1]), distance(p[3], p[2])).round();
  final h = math.max(distance(p[0], p[3]), distance(p[1], p[2])).round();
  if (w < 30 || h < 30) {
    throw const FormatException('Select a larger document area.');
  }
  var out = img.copyRectify(
    image,
    topLeft: p[0],
    topRight: p[1],
    bottomRight: p[2],
    bottomLeft: p[3],
    toImage: img.Image(width: w, height: h),
    interpolation: img.Interpolation.linear,
  );
  out = applyScanFilter(out, '${data['filter']}');
  return Uint8List.fromList(img.encodeJpg(out, quality: 92));
}

class CornerPainter extends CustomPainter {
  final List<Offset> points;
  CornerPainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(points[0].dx * size.width, points[0].dy * size.height);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    path.close();
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addPath(path, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      shade,
      Paint()..color = Colors.black.withValues(alpha: .45),
    );
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        Paint()..color = Colors.white24,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        Paint()..color = Colors.white24,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = scanBlue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CornerPainter oldDelegate) => true;
}

Map<String, dynamic> rotateScan(Uint8List bytes) {
  final image = img.copyRotate(img.decodeImage(bytes)!, angle: 90);
  return {
    'bytes': Uint8List.fromList(img.encodeJpg(image, quality: 95)),
    'ratio': image.width / image.height,
  };
}

List<List<double>> detectScanCorners(Uint8List bytes) {
  final image = img.copyResize(img.decodeImage(bytes)!, width: 240);
  final w = image.width, h = image.height;
  double luminance(int x, int y) {
    final p = image.getPixel(x, y);
    return .299 * p.r + .587 * p.g + .114 * p.b;
  }

  double sum = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      sum += luminance(x, y);
    }
  }
  final threshold = (sum / (w * h) + 12).clamp(110, 215);
  final visited = Uint8List(w * h);
  List<int> largest = [];
  for (var start = 0; start < w * h; start++) {
    if (visited[start] != 0) continue;
    visited[start] = 1;
    if (luminance(start % w, start ~/ w) < threshold) continue;
    final component = <int>[start];
    for (var k = 0; k < component.length; k++) {
      final index = component[k], x = index % w, y = index ~/ w;
      for (final n in [
        if (x > 0) index - 1,
        if (x < w - 1) index + 1,
        if (y > 0) index - w,
        if (y < h - 1) index + w,
      ]) {
        if (visited[n] != 0) continue;
        visited[n] = 1;
        if (luminance(n % w, n ~/ w) >= threshold) component.add(n);
      }
    }
    if (component.length > largest.length) largest = component;
  }
  if (largest.length < w * h * .08) {
    return [
      [0, 0],
      [1, 0],
      [1, 1],
      [0, 1],
    ];
  }
  final corners = [largest.first, largest.first, largest.first, largest.first];
  for (final p in largest) {
    final x = p % w, y = p ~/ w;
    if (x + y < corners[0] % w + corners[0] ~/ w) corners[0] = p;
    if (x - y > corners[1] % w - corners[1] ~/ w) corners[1] = p;
    if (x + y > corners[2] % w + corners[2] ~/ w) corners[2] = p;
    if (x - y < corners[3] % w - corners[3] ~/ w) corners[3] = p;
  }
  final points = corners
      .map((p) => [(p % w) / (w - 1), (p ~/ w) / (h - 1)])
      .toList();
  for (var i = 0; i < 4; i++) {
    final a = points[i], b = points[(i + 1) % 4], c = points[(i + 2) % 4];
    if ((b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]) <= 0) {
      return [
        [0, 0],
        [1, 0],
        [1, 1],
        [0, 1],
      ];
    }
  }
  return points;
}

class ScanModeArtwork extends StatelessWidget {
  final String kind;
  const ScanModeArtwork({super.key, required this.kind});
  @override
  Widget build(BuildContext context) {
    final asset = switch (kind) {
      'Passport' => 'scan_passport',
      'ID Card' => 'scan_id_card',
      _ => 'scan_bank_card',
    };
    return Image.asset(
      'assets/tool_icons_3d/$asset.png',
      height: 70,
      fit: BoxFit.contain,
      cacheHeight: (70 * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
        1,
        384,
      ),
      semanticLabel: kind,
    );
  }
}

img.Image applyScanFilter(img.Image out, String filter) {
  switch (filter) {
    case 'Auto':
      out = img.adjustColor(out, contrast: 1.2, brightness: 1.05);
    case 'Magic Color':
      out = img.adjustColor(out, contrast: 1.3, saturation: 1.25);
    case 'Grayscale':
      out = img.grayscale(out);
    case 'Black & White':
      out = img.grayscale(out);
      for (final pixel in out) {
        final v = pixel.r > 150 ? 255 : 0;
        pixel.setRgb(v, v, v);
      }
  }
  return out;
}

Uint8List scanFilterPreview(Map<String, dynamic> data) {
  var image = img.decodeImage(data['bytes'] as Uint8List)!;
  if (image.width > 900 || image.height > 1200) {
    final scale = math.min(900 / image.width, 1200 / image.height);
    image = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
  }
  return Uint8List.fromList(
    img.encodeJpg(
      applyScanFilter(image, data['filter'] as String),
      quality: 90,
    ),
  );
}

class ScanSuccessPage extends StatefulWidget {
  final Uint8List image, pdf;
  final bool saved;
  const ScanSuccessPage({
    super.key,
    required this.image,
    required this.pdf,
    this.saved = false,
  });
  @override
  State<ScanSuccessPage> createState() => _ScanSuccessPageState();
}

class _ScanSuccessPageState extends State<ScanSuccessPage> {
  String? message;
  bool working = false;
  Future<void> save() async {
    setState(() => working = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save scanned PDF',
        fileName: 'scanned-page.pdf',
        bytes: widget.pdf,
      );
      if (mounted) {
        setState(
          () => message = kIsWeb
              ? 'Download started.'
              : path == null
              ? 'Save canceled.'
              : 'PDF saved successfully.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = cleanError(e));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> share() async {
    setState(() => working = true);
    try {
      await Printing.sharePdf(bytes: widget.pdf, filename: 'scanned-page.pdf');
    } catch (e) {
      if (mounted) setState(() => message = cleanError(e));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const GlassAppBar(title: Text('Scan complete')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFF35C779),
              child: Icon(Icons.check_rounded, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 18),
            const Text(
              'Scan completed!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.saved
                  ? 'Saved automatically in My files. Your PDF is ready to share.'
                  : 'Your scanned page is ready to save and share as PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                widget.image,
                height: 320,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            GlassCard(
              child: ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: brandPurple,
                ),
                title: const Text('scanned-page.pdf'),
                subtitle: Text('${fileSize(widget.pdf.length)} - 1 page'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: working ? null : save,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: working ? null : share,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            if (working)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(message!, textAlign: TextAlign.center),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: working ? null : () => Navigator.pop(context, true),
              child: const Text('Continue scanning'),
            ),
          ],
        ),
      ),
    ),
  );
}
