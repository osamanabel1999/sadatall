import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Records a short voice message and returns the recorded [File], or null
/// if the user cancels. Self-contained (no per-mode theming) so it can live
/// in the shared chat module.
Future<File?> showVoiceRecorderSheet(BuildContext context, {required Color accentColor}) {
  return showModalBottomSheet<File>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => _VoiceRecorderSheet(accentColor: accentColor),
  );
}

class _VoiceRecorderSheet extends StatefulWidget {
  final Color accentColor;
  const _VoiceRecorderSheet({required this.accentColor});

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;
  String? _path;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _recording = true;
      _path = path;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  Future<void> _stopAndSend() async {
    await _recorder.stop();
    _timer?.cancel();
    if (mounted && _path != null) Navigator.pop(context, File(_path!));
  }

  Future<void> _cancel() async {
    await _recorder.stop();
    _timer?.cancel();
    if (_path != null) {
      try {
        await File(_path!).delete();
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  String get _formatted => '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 48, color: _recording ? Colors.red : widget.accentColor),
            const SizedBox(height: 12),
            Text(_formatted, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 32),
                  onPressed: _cancel,
                ),
                IconButton(
                  icon: Icon(Icons.check_circle, color: widget.accentColor, size: 40),
                  onPressed: _recording ? _stopAndSend : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
