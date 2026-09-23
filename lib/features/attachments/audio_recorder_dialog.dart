import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// Records an audio clip to [targetPath] and returns the path on success, or
/// null if cancelled / permission denied. Handles record → stop → save.
Future<String?> showAudioRecorderDialog(
  BuildContext context, {
  required String targetPath,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AudioRecorderDialog(targetPath: targetPath),
  );
}

class _AudioRecorderDialog extends StatefulWidget {
  const _AudioRecorderDialog({required this.targetPath});
  final String targetPath;

  @override
  State<_AudioRecorderDialog> createState() => _AudioRecorderDialogState();
}

class _AudioRecorderDialogState extends State<_AudioRecorderDialog> {
  final _recorder = AudioRecorder();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'Microphone permission denied.');
        return;
      }
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: widget.targetPath,
      );
      setState(() {
        _recording = true;
        _error = null;
        _elapsed = Duration.zero;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      setState(() => _error = 'Could not start recording.');
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Record audio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _recording ? Icons.mic : Icons.mic_none,
            size: 56,
            color: _recording ? scheme.error : scheme.primary,
          ),
          const SizedBox(height: 12),
          Text(_format(_elapsed),
              style: Theme.of(context).textTheme.headlineSmall),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!_recording)
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.fiber_manual_record),
            label: const Text('Record'),
          )
        else
          FilledButton.icon(
            onPressed: _stopAndSave,
            icon: const Icon(Icons.stop),
            label: const Text('Stop & save'),
          ),
      ],
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
