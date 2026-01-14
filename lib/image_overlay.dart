import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

class ImageOverlayPage extends StatefulWidget {
  const ImageOverlayPage({super.key});

  @override
  State<ImageOverlayPage> createState() => _ImageOverlayPageState();
}

class _ImageOverlayPageState extends State<ImageOverlayPage> {
  XFile? _background;
  XFile? _overlay;
  Uint8List? _backgroundBytes;
  Uint8List? _overlayBytes;
  Uint8List? _resultBytes;
  bool _processing = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickBackground() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _background = picked;
      _backgroundBytes = bytes;
    });
  }

  Future<void> _pickOverlay() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _overlay = picked;
      _overlayBytes = bytes;
    });
  }

  Future<void> _compose() async {
    if (_background == null || _overlay == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please pick both background and overlay images.'),
      ));
      return;
    }

    setState(() {
      _processing = true;
      _resultBytes = null;
    });

    if (kIsWeb) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('FFmpeg overlay is not supported on Flutter Web.'),
      ));
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/overlay_out_${DateTime.now().millisecondsSinceEpoch}.png';

    // Place overlay at bottom-right with 10px margin
    final filter = 'overlay=W-w-10:H-h-10';

    final command = '-y -i "${_background!.path}" -i "${_overlay!.path}" -filter_complex "$filter" "$outPath"';

    await FFmpegKit.executeAsync(command, (session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        // Read the generated file into bytes to display without dart:io
        final outXFile = XFile(outPath);
        final bytes = await outXFile.readAsBytes();
        setState(() {
          _resultBytes = bytes;
          _processing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Image composed successfully.'),
        ));
      } else {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('FFmpeg failed: rc=${returnCode?.getValue() ?? 'unknown'}'),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Overlay')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _pickBackground,
              icon: const Icon(Icons.photo),
              label: const Text('Pick Background Image'),
            ),
            const SizedBox(height: 8),
            if (_backgroundBytes != null)
              Image.memory(_backgroundBytes!, height: 200, fit: BoxFit.contain),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickOverlay,
              icon: const Icon(Icons.layers),
              label: const Text('Pick Overlay Image'),
            ),
            const SizedBox(height: 8),
            if (_overlayBytes != null)
              Image.memory(_overlayBytes!, height: 150, fit: BoxFit.contain),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: (_processing || kIsWeb) ? null : _compose,
              icon: _processing ? const SizedBox.shrink() : const Icon(Icons.play_arrow),
              label: Text(kIsWeb ? 'Compose (native only)' : (_processing ? 'Processing...' : 'Compose Overlay')),
            ),
            const SizedBox(height: 20),
            if (_resultBytes != null) ...[
              const Text('Result:'),
              const SizedBox(height: 8),
              Image.memory(_resultBytes!, height: 300, fit: BoxFit.contain),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // Open/share could be added here
                },
                icon: const Icon(Icons.save),
                label: const Text('Save / Share (implement as needed)'),
              )
            ]
          ],
        ),
      ),
    );
  }
}
