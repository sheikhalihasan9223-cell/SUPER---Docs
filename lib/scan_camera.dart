import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const scanBlue = Color(0xFF087DF1);

class ScanCamera extends StatefulWidget {
  final Future<Uint8List?> Function(Uint8List) edit;
  final String? initialCard;
  const ScanCamera({super.key, required this.edit, this.initialCard});
  @override
  State<ScanCamera> createState() => _ScanCameraState();
}

class _ScanCameraState extends State<ScanCamera> with WidgetsBindingObserver {
  CameraController? controller;
  final List<Uint8List> pages = [];
  String mode = 'Single', card = 'ID Card';
  String? error;
  bool busy = false, flash = false, guides = true;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    if (widget.initialCard != null) {
      mode = 'Scan ID';
      card = widget.initialCard!;
    }
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    final request = ++generation;
    CameraController? next;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera available');
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      next = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await next.initialize();
      if (!mounted || request != generation) {
        await next.dispose();
        return;
      }
      setState(() {
        controller = next;
        flash = false;
        error = null;
      });
    } catch (e) {
      await next?.dispose();
      if (mounted && request == generation) {
        setState(
          () => error =
              'Camera unavailable. Allow camera access in device settings, or import a photo.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      generation++;
      final previous = controller;
      controller = null;
      previous?.dispose();
    } else if (state == AppLifecycleState.resumed &&
        controller == null &&
        !busy) {
      initialize();
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  Future<void> capture({bool import = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final image = import
          ? await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 2400,
              imageQuality: 95,
            )
          : await controller?.takePicture();
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      await controller?.pausePreview();
      final edited = await widget.edit(bytes);
      if (!mounted) return;
      if (edited != null) {
        pages.add(edited);
        if (mode != 'Multi') {
          Navigator.pop(context, pages);
          return;
        }
      }
      await controller?.resumePreview();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not capture the page. Try again or import a photo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (controller == null) initialize();
      }
    }
  }

  Future<void> toggleFlash() async {
    try {
      await controller?.setFlashMode(flash ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => flash = !flash);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Flash is unavailable on this camera.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.light(),
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Scan document', style: TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Flash',
            onPressed: busy || controller == null ? null : toggleFlash,
            icon: Icon(flash ? Icons.flash_on : Icons.flash_off),
          ),
          IconButton(
            tooltip: 'Guides',
            onPressed: () => setState(() => guides = !guides),
            icon: const Icon(Icons.crop),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: controller?.value.isInitialized == true
                      ? Center(child: CameraPreview(controller!))
                      : Center(
                          child: error == null
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                        ),
                ),
                if (guides)
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: .86,
                      heightFactor: mode == 'Scan ID'
                          ? (card == 'Passport' ? .58 : .34)
                          : .76,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70, width: 2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 24,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      if (mode == 'Scan ID')
                        Wrap(
                          spacing: 6,
                          children: ['Passport', 'ID Card', 'Bank card']
                              .map(
                                (value) => ChoiceChip(
                                  label: Text(value),
                                  selected: card == value,
                                  onSelected: busy
                                      ? null
                                      : (_) => setState(() => card = value),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        mode == 'Multi'
                            ? '${pages.length} pages captured ? Capture more or tap Done'
                            : 'Align the document and tap the shutter',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: ['Single', 'Multi', 'Scan ID']
                        .map(
                          (value) => Expanded(
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() => mode = value),
                              child: Text(
                                value,
                                style: TextStyle(
                                  color: mode == value
                                      ? scanBlue
                                      : Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (error != null && controller != null)
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(
                        onPressed: busy ? null : () => capture(import: true),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: Colors.black87,
                            ),
                            Text(
                              'Import',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: 'Capture photo',
                        button: true,
                        child: GestureDetector(
                          onTap: busy || controller == null ? null : capture,
                          child: Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: scanBlue, width: 3),
                            ),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: scanBlue,
                                shape: BoxShape.circle,
                              ),
                              child: busy
                                  ? const Padding(
                                      padding: EdgeInsets.all(18),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 76,
                        child: TextButton(
                          onPressed: busy || pages.isEmpty
                              ? null
                              : () => Navigator.pop(context, pages),
                          child: Text('Done (${pages.length})'),
                        ),
                      ),
                    ],
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
