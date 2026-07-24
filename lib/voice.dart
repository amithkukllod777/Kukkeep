import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'note_colors.dart';
import 'l10n/strings.dart';

/// Records a voice memo through a modal sheet and returns the recorded file
/// path (AAC/m4a in the temp dir), or null if the user cancelled or the mic
/// permission was denied. The caller uploads the file as a note attachment.
Future<String?> recordVoiceSheet(BuildContext context) {
  return showModalBottomSheet<String?>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _RecorderSheet(),
  );
}

class _RecorderSheet extends StatefulWidget {
  const _RecorderSheet();
  @override
  State<_RecorderSheet> createState() => _RecorderSheetState();
}

class _RecorderSheetState extends State<_RecorderSheet> {
  final AudioRecorder _rec = AudioRecorder();
  bool _recording = false;
  String? _path;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (!await _rec.hasPermission()) {
        if (mounted) Navigator.pop(context, null);
        return;
      }
      final p = '${Directory.systemTemp.path}/kk_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: p);
      _path = p;
      if (!mounted) return;
      setState(() => _recording = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (_) {
      if (mounted) Navigator.pop(context, null);
    }
  }

  Future<void> _stop({required bool save}) async {
    _timer?.cancel();
    String? out;
    try { out = await _rec.stop(); } catch (_) {}
    try { await _rec.dispose(); } catch (_) {}
    if (!mounted) return;
    Navigator.pop(context, save ? (out ?? _path) : null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _fmt {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.mic, size: 44, color: _recording ? kError : kBrand),
          const SizedBox(height: 10),
          Text(_fmt, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: kTextPrimary)),
          const SizedBox(height: 6),
          Text(_recording ? tr('recording') : tr('starting'), style: const TextStyle(color: kTextMuted)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            TextButton(onPressed: () => _stop(save: false), child: Text(tr('cancel'))),
            FilledButton.icon(
              onPressed: _recording ? () => _stop(save: true) : null,
              icon: const Icon(Icons.stop),
              label: Text(tr('stop_attach')),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Inline play/pause control for an audio (voice) attachment.
class AudioChip extends StatefulWidget {
  final String url;
  final String label;
  const AudioChip({super.key, required this.url, required this.label});
  @override
  State<AudioChip> createState() => _AudioChipState();
}

class _AudioChipState extends State<AudioChip> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
      } else {
        await _player.play(UrlSource(widget.url));
        if (mounted) setState(() => _playing = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120, height: 72, padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _toggle,
          icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle, size: 30, color: kBrand),
          tooltip: _playing ? tr('pause') : tr('play'),
        ),
        Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.black54)),
      ]),
    );
  }
}
