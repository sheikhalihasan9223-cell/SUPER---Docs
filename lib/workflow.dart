import 'glass.dart';
import 'on_device_enhancement.dart';
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'models.dart';
import 'processor.dart';
import 'store.dart';
import 'file_storage.dart';
import 'tool_icon.dart';
import 'document_markup.dart';

class ToolScreen extends StatefulWidget {
  final DocTool tool;
  final AppStore store;
  final DocFile? initial;
  const ToolScreen({
    super.key,
    required this.tool,
    required this.store,
    this.initial,
  });
  @override
  State<ToolScreen> createState() => _ToolScreenState();
}

class _ToolScreenState extends State<ToolScreen> {
  final List<DocFile> files = [];
  final range = TextEditingController();
  final password = TextEditingController();
  final text = TextEditingController();
  final width = TextEditingController(text: '1200');
  bool useDeviceAi = supportsDeviceAi;
  DeviceEnhancementTask? enhancementTask;
  double aiProgress = 0;
  int upscale = 2;
  bool get deviceEnhancement => tool.id == 'image_enhance';
  bool get localProcessing => tool.local;
  String pageSize = 'A4',
      format = 'PNG',
      compression = 'Recommended',
      position = 'Bottom center';
  double quality = 80, opacity = .25;
  int angle = 90;
  bool stripMetadata = true, busy = false;
  String? error;
  String language = 'English', presentationMode = 'Page images';
  bool ocrFallback = true;
  List<Map<String, dynamic>> operations = [];
  int generation = 0;
  http.Client? client;
  DocTool get tool => widget.tool;
  bool get images => tool.image || tool.id == 'image_pdf';
  bool get multi => images || tool.id == 'merge';
  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      files.add(widget.initial!);
    }
  }

  @override
  void dispose() {
    generation++;
    enhancementTask?.cancel();
    client?.close();
    range.dispose();
    password.dispose();
    text.dispose();
    width.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        allowMultiple: multi,
        withData: true,
        type: FileType.custom,
        allowedExtensions: tool.inputExtensions,
      );
      if (selection == null || !mounted) {
        return;
      }
      final incoming = <DocFile>[];
      for (final f in selection.files) {
        if (f.bytes == null) {
          throw StateError('Could not read ${f.name}. Please select it again.');
        }
        incoming.add(
          DocFile(
            id: '${DateTime.now().microsecondsSinceEpoch}-${incoming.length}',
            name: f.name,
            bytes: f.bytes!,
            created: DateTime.now(),
            tool: 'Imported',
          ),
        );
      }
      if ((multi ? files.length : 0) + incoming.length > 5) {
        throw StateError('This starter build supports up to 5 files per task.');
      }
      if (incoming.any((f) => f.bytes.length > 25 * 1024 * 1024) ||
          [
                ...(multi ? files : <DocFile>[]),
                ...incoming,
              ].fold<int>(0, (sum, f) => sum + f.bytes.length) >
              50 * 1024 * 1024) {
        throw StateError('Use files under 25 MB, with a total under 50 MB.');
      }
      setState(() {
        if (!multi) {
          files.clear();
        }
        files.addAll(incoming);
        operations = [];
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = cleanError(e));
      }
    }
  }

  Future<void> run() async {
    if (tool.id != 'create' && files.isEmpty) {
      setState(() => error = 'Select a file to get started.');
      return;
    }
    if (tool.id == 'merge' && files.length < 2) {
      setState(() => error = 'Select at least two PDFs to merge.');
      return;
    }
    if (tool.id == 'protect' && password.text.isEmpty) {
      setState(() => error = 'Enter a password for your PDF.');
      return;
    }
    if (['extract', 'organize'].contains(tool.id) &&
        range.text.trim().isEmpty) {
      setState(() => error = 'Enter the pages to keep, in the order you want.');
      return;
    }
    if (['edit', 'sign'].contains(tool.id) && operations.isEmpty) {
      setState(
        () => error = 'Place an annotation or signature on the page first.',
      );
      return;
    }
    if (deviceEnhancement && useDeviceAi && files.length != 1) {
      setState(() => error = 'Select one photo at a time for AI enhancement.');
      return;
    }
    final options = <String, dynamic>{
      'upscale': upscale,
      'operations': operations,
      'language': {
        'English': 'eng',
        'Arabic': 'ara',
        'Hindi': 'hin',
        'Spanish': 'spa',
        'French': 'fra',
        'Portuguese': 'por',
        'Indonesian': 'ind',
        'Turkish': 'tur',
        'Urdu': 'urd',
      }[language],
      'ocrFallback': ocrFallback,
      'presentationMode': presentationMode,
      'range': range.text.trim(),
      'password': password.text,
      'text': text.text,
      'width': width.text,
      'pageSize': pageSize,
      'format': format,
      'quality': quality,
      'angle': angle,
      'stripMetadata': stripMetadata,
      'compression': compression,
      'opacity': opacity,
      'position': position,
    };
    final ticket = ++generation;
    setState(() {
      busy = true;
      aiProgress = 0;
      error = null;
    });
    client = http.Client();
    final taskClient = client!;
    try {
      final result = deviceEnhancement && useDeviceAi
          ? ProcessingResult(
              await (enhancementTask = DeviceEnhancementTask()).run(
                files.single.bytes,
                upscale,
                onProgress: (value) {
                  if (mounted && ticket == generation) {
                    setState(() => aiProgress = value);
                  }
                },
              ),
              'enhanced-ai.png',
            )
          : localProcessing
          ? await processLocal(tool, files, options)
          : await processRemote(
              taskClient,
              widget.store.endpoint,
              tool,
              files,
              options,
              headers: widget.store.remoteHeaders,
            );
      if (!mounted || ticket != generation) {
        return;
      }
      final file = DocFile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: result.name,
        bytes: result.bytes,
        created: DateTime.now(),
        tool: tool.name,
      );
      setState(() => busy = false);
      password.clear();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            file: file,
            store: widget.store,
            originalSize: files.fold<int>(0, (sum, f) => sum + f.bytes.length),
          ),
        ),
      );
    } on TimeoutException {
      if (mounted && ticket == generation) {
        setState(() {
          busy = false;
          error =
              'The service took too long. Try fewer pages or a smaller file.';
        });
      }
    } catch (e) {
      if (mounted && ticket == generation) {
        setState(() {
          busy = false;
          error = localProcessing
              ? cleanError(e)
              : e is http.ClientException
              ? 'Cannot connect to the processing service at ${widget.store.endpoint}. Start the service on your computer. For an Android emulator, use http://10.0.2.2:8000 in Settings. For a phone, use your computer?s reachable service address.'
              : cleanError(e);
        });
      }
    } finally {
      taskClient.close();
      if (identical(client, taskClient)) {
        client = null;
      }
    }
  }

  void cancel() {
    generation++;
    enhancementTask?.cancel();
    client?.close();
    setState(() {
      busy = false;
      error = 'Task canceled. Your source files are unchanged.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GlassAppBar(title: Text(tool.name)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tool.color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: 112,
                    child: ToolGlyph(tool: tool, height: 68),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool.name,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        tool.description,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...[
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  step(1, 'Select'),
                  step(2, 'Configure'),
                  step(3, 'Process'),
                  step(4, 'Save & share'),
                ],
              ),
              const SizedBox(height: 24),
              if (tool.id != 'create') ...[
                GlassCard(
                  child: InkWell(
                    onTap: busy ? null : pick,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 40,
                            color: tool.color,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            files.isEmpty
                                ? 'Start with your ${tool.officeInput
                                      ? 'Office document'
                                      : images
                                      ? 'images'
                                      : 'PDF'}'
                                : 'Add ${multi ? 'more files' : 'a different file'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            images
                                ? 'JPG, PNG, WebP, GIF, BMP, TIFF · up to 5 files'
                                : '${tool.inputExtensions.join(', ').toUpperCase()} · up to 25 MB per file',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: busy ? null : pick,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Select files'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.store.files.any(
                  (f) => images
                      ? ['jpg', 'jpeg', 'png'].contains(f.extension)
                      : tool.inputExtensions.contains(f.extension),
                ))
                  Wrap(
                    spacing: 8,
                    children: widget.store.files
                        .where(
                          (f) => images
                              ? ['jpg', 'jpeg', 'png'].contains(f.extension)
                              : tool.inputExtensions.contains(f.extension),
                        )
                        .take(3)
                        .map(
                          (f) => ActionChip(
                            avatar: const Icon(Icons.history, size: 16),
                            label: SizedBox(
                              width: 130,
                              child: Text(
                                f.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    if (!multi) {
                                      files.clear();
                                      operations = [];
                                    }
                                    if (files.length < 5) {
                                      files.add(f);
                                    }
                                  }),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 12),
                for (var i = 0; i < files.length; i++)
                  GlassCard(
                    child: ListTile(
                      leading: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: brandPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      title: Text(
                        files[i].name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(fileSize(files[i].bytes.length)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (multi)
                            IconButton(
                              tooltip: 'Move up',
                              onPressed: busy || i == 0
                                  ? null
                                  : () => setState(() {
                                      final item = files.removeAt(i);
                                      files.insert(i - 1, item);
                                    }),
                              icon: const Icon(Icons.arrow_upward, size: 18),
                            ),
                          IconButton(
                            tooltip: 'Remove file',
                            onPressed: busy
                                ? null
                                : () => setState(() => files.removeAt(i)),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              AbsorbPointer(
                absorbing: busy,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ([
                      'ocr',
                      'pdf_word',
                      'pdf_excel',
                      'pdf_ppt',
                    ].contains(tool.id)) ...[
                      dropdown('OCR language', language, [
                        'English',
                        'Arabic',
                        'Hindi',
                        'Spanish',
                        'French',
                        'Portuguese',
                        'Indonesian',
                        'Turkish',
                        'Urdu',
                      ], (v) => language = v),
                      if (tool.id != 'ocr')
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Recognize scanned pages'),
                          value: ocrFallback,
                          onChanged: (v) => setState(() => ocrFallback = v),
                        ),
                      const Text(
                        'OCR supports up to 40 pages per task. Clear scans produce better results.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (tool.id == 'pdf_ppt')
                      dropdown('Slide content', presentationMode, [
                        'Page images',
                        'Editable text',
                      ], (v) => presentationMode = v),
                    if (['pdf_word', 'pdf_excel', 'pdf_ppt'].contains(tool.id))
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Word exports editable text, tables and embedded images. Excel extracts tables or plain text rows. PowerPoint page images preserve appearance; editable text may shift layout.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    if (['edit', 'sign'].contains(tool.id) && files.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(
                              tool.id == 'sign'
                                  ? 'Open signature editor'
                                  : 'Open annotation editor',
                            ),
                            onPressed: () async {
                              final edited =
                                  await Navigator.push<
                                    List<Map<String, dynamic>>
                                  >(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DocumentEditorScreen(
                                        file: files.first,
                                        signing: tool.id == 'sign',
                                        operations: operations,
                                      ),
                                    ),
                                  );
                              if (mounted && edited != null) {
                                setState(() => operations = edited);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${operations.length} items ready to apply',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    if ([
                      'split',
                      'extract',
                      'organize',
                      'rotate',
                      'pdf_jpg',
                      'numbers',
                      'watermark',
                    ].contains(tool.id)) ...[
                      TextField(
                        controller: range,
                        decoration: InputDecoration(
                          labelText: tool.id == 'organize'
                              ? 'Pages in the new order'
                              : 'Page range',
                          hintText: tool.id == 'organize'
                              ? '3,1,2 (omit pages to remove them)'
                              : '1-3,5 (blank = all pages)',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (tool.id == 'split')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Each selected page is exported as a separate PDF in a ZIP.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    if (tool.id == 'rotate')
                      dropdown('Rotation', '$angle', [
                        '90',
                        '180',
                        '270',
                      ], (v) => angle = int.parse(v)),
                    if (tool.id == 'compress') ...[
                      dropdown('Compression level', compression, [
                        'Low',
                        'Recommended',
                        'Extreme',
                      ], (v) => compression = v),
                      const Text(
                        'Lossless content compression; already optimized files may not shrink. Levels control image re-encoding quality.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                    if (tool.id == 'protect' || tool.id == 'unlock') ...[
                      TextField(
                        controller: password,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: tool.id == 'protect'
                              ? 'New open password (AES-256)'
                              : 'Current password',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Only process documents you own or have permission to modify. Passwords are used for this task only.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                    if (tool.id == 'watermark' || tool.id == 'create') ...[
                      TextField(
                        controller: text,
                        maxLines: tool.id == 'create' ? 10 : 2,
                        decoration: InputDecoration(
                          labelText: tool.id == 'create'
                              ? 'Document text (Latin characters)'
                              : 'Watermark text (Latin characters)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (tool.id == 'watermark') ...[
                      Text('Opacity: ${(opacity * 100).round()}%'),
                      Slider(
                        value: opacity,
                        min: .05,
                        max: 1,
                        onChanged: (v) => setState(() => opacity = v),
                      ),
                    ],
                    if (tool.id == 'numbers')
                      dropdown('Position', position, [
                        'Bottom center',
                        'Bottom left',
                        'Bottom right',
                        'Top center',
                        'Top left',
                        'Top right',
                      ], (v) => position = v),
                    if (tool.id == 'image_pdf' || tool.id == 'create')
                      dropdown('Page size', pageSize, [
                        'A4',
                        'Letter',
                      ], (v) => pageSize = v),
                    if (tool.id == 'image_convert')
                      dropdown('Output format', format, [
                        'PNG',
                        'GIF',
                        'BMP',
                        'TIFF',
                      ], (v) => format = v),
                    if (tool.id == 'image_resize') ...[
                      TextField(
                        controller: width,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Width in pixels',
                          helperText: 'Aspect ratio is preserved.',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (tool.image &&
                            ![
                              'image_convert',
                              'image_enhance',
                            ].contains(tool.id) ||
                        tool.id == 'pdf_jpg') ...[
                      Text('JPEG quality: ${quality.round()}%'),
                      Slider(
                        value: quality,
                        min: 10,
                        max: 100,
                        divisions: 18,
                        onChanged: (v) => setState(() => quality = v),
                      ),
                    ],
                    if (deviceEnhancement && supportsDeviceAi)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('On-device AI enhancement'),
                        subtitle: const Text(
                          'Works offline. Large photos are resized to 512 pixels before 2x or 4x enhancement. Turn off to keep original size with basic enhancement.',
                        ),
                        value: useDeviceAi,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => useDeviceAi = v),
                      ),
                    if (deviceEnhancement && useDeviceAi)
                      DropdownButtonFormField<int>(
                        initialValue: upscale,
                        decoration: const InputDecoration(
                          labelText: 'Enlargement',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 2,
                            child: Text('2x resolution'),
                          ),
                          DropdownMenuItem(
                            value: 4,
                            child: Text('4x resolution'),
                          ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) => setState(() => upscale = v ?? 2),
                      ),
                    if (tool.image)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Remove image metadata'),
                        subtitle: const Text(
                          'Strip EXIF details from the output',
                        ),
                        value: stripMetadata,
                        onChanged: (v) => setState(() => stripMetadata = v),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: brandPurple.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      localProcessing
                          ? Icons.shield_outlined
                          : Icons.cloud_upload_outlined,
                      color: brandPurple,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        localProcessing
                            ? 'Processed on your device. No upload needed.'
                            : 'This task uploads your selected PDFs to:\n${widget.store.endpoint}\nTemporary conversion files are deleted after processing.',
                        style: const TextStyle(fontSize: 12, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (busy) ...[
                LinearProgressIndicator(
                  value: deviceEnhancement && useDeviceAi && aiProgress > 0
                      ? aiProgress
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  deviceEnhancement && useDeviceAi
                      ? 'Enhancing on your phone: ${(aiProgress * 100).round()}%'
                      : 'Processing your files. Large documents can take longer.',
                ),
                TextButton(onPressed: cancel, child: const Text('Cancel')),
              ] else
                FilledButton.icon(
                  onPressed: run,
                  icon: Icon(tool.icon, size: 20),
                  label: Text(
                    localProcessing
                        ? tool.name
                        : 'Upload & ${tool.name.toLowerCase()}',
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
  Widget step(int n, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 12,
        backgroundColor: brandPurple.withValues(alpha: .1),
        child: Text(
          '$n',
          style: const TextStyle(color: brandPurple, fontSize: 11),
        ),
      ),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ],
  );
  Widget dropdown(
    String label,
    String value,
    List<String> options,
    void Function(String) update,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() => update(v));
        }
      },
    ),
  );
}

String cleanError(Object e) => e.toString().replaceFirst(
  RegExp(r'^(Bad state: |FormatException: |Exception: )'),
  '',
);

class ResultScreen extends StatefulWidget {
  final DocFile file;
  final AppStore store;
  final int? originalSize;
  const ResultScreen({
    super.key,
    required this.file,
    required this.store,
    this.originalSize,
  });
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String? message;
  @override
  void initState() {
    super.initState();
    saveHistory();
  }

  bool saving = false, showPreview = false;
  Future<void> openExternal() async {
    if (kIsWeb) {
      await export();
      return;
    }
    try {
      await openSavedFile(widget.file.name, widget.file.bytes);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              message = '${cleanError(e)} Download a copy to open it manually.',
        );
      }
    }
  }

  Future<void> export() async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save your document',
        fileName: widget.file.name,
        bytes: widget.file.bytes,
      );
      if (mounted) {
        setState(
          () => message = kIsWeb
              ? 'Download started. Check your browser downloads.'
              : path == null
              ? 'Save dialog closed.'
              : 'Exported successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = cleanError(e));
      }
    }
  }

  Future<void> saveHistory() async {
    setState(() => saving = true);
    try {
      await widget.store.save(widget.file);
      if (mounted) {
        setState(() => message = 'Saved in My files.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = cleanError(e));
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget _resultAction(IconData icon, String label, VoidCallback onTap) =>
      GlassCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, color: brandPurple),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final before = widget.originalSize;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(showPreview ? f.name : ''),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!showPreview) ...[
                SizedBox(
                  height: 230,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/illustrations/workspace-hero.png',
                        width: 230,
                      ),
                      Positioned(
                        right: 55,
                        bottom: 25,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF35C779),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x3035C779),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Conversion Completed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your ${f.extension.toUpperCase()} is ready.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_rounded,
                          size: 38,
                          color: brandPurple,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${fileSize(f.bytes.length)}${before != null && before > f.bytes.length ? ' ? ${((1 - f.bytes.length / before) * 100).round()}% smaller' : ''}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed:
                      [
                        'pdf',
                        'jpg',
                        'jpeg',
                        'png',
                        'gif',
                        'bmp',
                        'webp',
                        'txt',
                      ].contains(f.extension)
                      ? () => setState(() => showPreview = true)
                      : openExternal,
                  child: Text(
                    f.extension == 'pdf'
                        ? 'View PDF'
                        : ['docx', 'xlsx', 'pptx', 'zip'].contains(f.extension)
                        ? kIsWeb
                              ? 'Download document'
                              : 'Open document'
                        : 'View document',
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (showPreview)
                if (f.extension == 'pdf' && f.tool == 'Protect PDF')
                  const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.all(36),
                      child: Column(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 48,
                            color: brandPurple,
                          ),
                          SizedBox(height: 12),
                          Text('Your PDF is password protected.'),
                          SizedBox(height: 8),
                          Text(
                            'Save the file and use your password to open it.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (f.extension == 'pdf')
                  SizedBox(
                    height: 440,
                    child: PdfPreview(
                      build: (_) => f.bytes,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      allowPrinting: false,
                      allowSharing: false,
                      canDebug: false,
                    ),
                  )
                else if ([
                  'jpg',
                  'jpeg',
                  'png',
                  'gif',
                  'bmp',
                  'webp',
                ].contains(f.extension))
                  Container(
                    height: 380,
                    padding: const EdgeInsets.all(16),
                    child: Image.memory(
                      f.bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text(
                          'Preview unavailable; export the image to open it.',
                        ),
                      ),
                    ),
                  )
                else if (f.extension == 'txt')
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(utf8.decode(f.bytes)),
                    ),
                  )
                else
                  const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_zip_outlined,
                            size: 48,
                            color: brandPurple,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Save to your device to open the converted file.',
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (f.extension == 'pdf')
                    Expanded(
                      child: _resultAction(Icons.ios_share, 'Share', () async {
                        try {
                          await Printing.sharePdf(
                            bytes: f.bytes,
                            filename: f.name,
                          );
                        } catch (e) {
                          if (mounted) setState(() => message = cleanError(e));
                        }
                      }),
                    ),
                  Expanded(
                    child: _resultAction(
                      Icons.folder_outlined,
                      'Save to Files',
                      export,
                    ),
                  ),
                  Expanded(
                    child: _resultAction(
                      Icons.more_horiz,
                      'More',
                      () => showModalBottomSheet<void>(
                        context: context,
                        builder: (sheetContext) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.bookmark_outline),
                                title: const Text('Save in My files'),
                                onTap: saving
                                    ? null
                                    : () {
                                        Navigator.pop(sheetContext);
                                        saveHistory();
                                      },
                              ),
                              ListTile(
                                leading: const Icon(Icons.download_outlined),
                                title: const Text('Save to device'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  export();
                                },
                              ),
                              if (f.extension == 'txt')
                                ListTile(
                                  leading: const Icon(Icons.copy),
                                  title: const Text('Copy text'),
                                  onTap: () async {
                                    Navigator.pop(sheetContext);
                                    await Clipboard.setData(
                                      ClipboardData(text: utf8.decode(f.bytes)),
                                    );
                                    if (mounted) {
                                      setState(() => message = 'Text copied.');
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Center(child: Text(message!)),
                ),
              if (f.extension == 'pdf') ...[
                const SizedBox(height: 28),
                const Text(
                  'Keep the momentum',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: tools
                      .where(
                        (t) => [
                          'compress',
                          'numbers',
                          'protect',
                          'watermark',
                        ].contains(t.id),
                      )
                      .map(
                        (t) => ActionChip(
                          avatar: Icon(t.icon, size: 18, color: t.color),
                          label: Text(t.name),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ToolScreen(
                                tool: t,
                                store: widget.store,
                                initial: f,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
