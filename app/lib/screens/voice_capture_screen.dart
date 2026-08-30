import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../services/api_error.dart';
import '../services/expense_service.dart';
import 'add_expense_screen.dart';

/// Captures a short audio clip from the microphone. Abstraced so widget tests
/// can supply a fake without touching the platform `record` channels.
abstract class VoiceRecorder {
  Future<bool> hasPermission();
  Future<void> start();
  /// Stops recording and returns the captured audio, or null if none.
  Future<({Uint8List bytes, String mimeType})?> stop();
  Future<void> dispose();
}

/// Real microphone capture backed by the `record` package (WAV output).
class RecordVoiceRecorder implements VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final path =
        '${Directory.systemTemp.path}/capture_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _path = path;
  }

  @override
  Future<({Uint8List bytes, String mimeType})?> stop() async {
    final path = await _recorder.stop() ?? _path;
    if (path == null) return null;
    return (bytes: await File(path).readAsBytes(), mimeType: 'audio/wav');
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Mic-capture entry point (ticket 03). Records a short utterance with the
/// device microphone, sends it to the backend voice pipeline, and on success
/// drops the User straight onto the prefilled add-expense edit screen with any
/// low-confidence fields highlighted.
class VoiceCaptureScreen extends StatefulWidget {
  const VoiceCaptureScreen({
    super.key,
    required this.service,
    required this.onConfirm,
    this.recorder,
  });

  final ExpenseService service;

  /// Called after a voice-driven Expense is confirmed (e.g. refresh the Ledger).
  final VoidCallback onConfirm;

  /// Injectable for tests; defaults to the real microphone.
  final VoiceRecorder? recorder;

  @override
  State<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends State<VoiceCaptureScreen> {
  late final VoiceRecorder _recorder = widget.recorder ?? RecordVoiceRecorder();
  bool _recording = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_busy) return;

    if (!_recording) {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        setState(() => _error = 'Microphone permission was denied');
        return;
      }
      setState(() {
        _error = null;
        _recording = true;
      });
      try {
        await _recorder.start();
      } catch (e) {
        setState(() {
          _recording = false;
          _error = 'Could not start recording. Your microphone may be in use.';
        });
      }
      return;
    }

    // Stop recording, then send it for capture.
    setState(() => _busy = true);
    try {
      final audio = await _recorder.stop();
      setState(() => _recording = false);
      if (audio == null) {
        setState(() => _error = 'Recording produced no audio');
        return;
      }
      final draft = await widget.service.captureVoice(
        audioBytes: audio.bytes,
        mimeType: audio.mimeType,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Confirm expense')),
            // AddExpenseScreen has no Scaffold of its own (it lives nested in
            // the Home tab), so wrap it for standalone use as a route.
            body: AddExpenseScreen(
              service: widget.service,
              draft: draft,
              onAdded: widget.onConfirm,
            ),
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Voice capture')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, size: 64),
              const SizedBox(height: 12),
              Text(
                _recording
                    ? 'Listening… tap to finish'
                    : 'Tap the mic and say the expense',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              IconButton.filled(
                onPressed: _busy ? null : _toggleRecording,
                iconSize: 56,
                icon: _busy
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Icon(
                        _recording ? Icons.stop : Icons.mic,
                        color: colorScheme.onPrimary,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                'Say it like: “I paid one hundred rupees for dinner with Alice.”',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
