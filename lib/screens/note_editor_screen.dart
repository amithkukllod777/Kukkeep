import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../api.dart';
import '../auth_messages.dart';
import '../l10n/strings.dart';
import '../models.dart';
import '../note_colors.dart';
import '../note_templates.dart';
import '../notifications.dart';
import '../share_export.dart';
import '../voice.dart';
import 'draw_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  /// Seed content for a brand-new note (ignored when [note] is non-null).
  final NoteTemplate? template;
  /// View-only mode (a note shared with me that I may not edit).
  final bool readOnly;
  /// Seed body text for a brand-new note (e.g. content shared from another app).
  final String? initialText;
  const NoteEditorScreen({super.key, this.note, this.template, this.readOnly = false, this.initialText});
  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> with WidgetsBindingObserver {
  late TextEditingController _title;
  late TextEditingController _body;
  late String _type;
  late List<ChecklistItem> _items;
  late String _color;
  late List<String> _labels;
  DateTime? _reminder;
  String _repeat = 'none'; // none | daily | weekly | monthly (reminder recurrence)
  late bool _pinned;
  final _labelInput = TextEditingController();
  bool _saving = false;

  // Persistent per-item controllers/focus nodes so the checklist keeps its text,
  // cursor and focus across rebuilds (and Enter can move focus to the new line).
  final List<TextEditingController> _itemCtrls = [];
  final List<FocusNode> _itemNodes = [];

  int? _transcribing; // id of the audio attachment currently being transcribed

  // Editor text is always on a light pastel note background, so ink stays dark
  // regardless of the app's light/dark theme.
  static const Color _ink = Color(0xFF1E2230);
  static const Color _inkFaint = Colors.black38;

  // Attachments (image / file notes + OCR).
  List<Attachment> _attachments = [];
  bool _uploading = false;

  // The note's server id. Null for a brand-new note until it's first saved —
  // either by tapping Save, or automatically when the first attachment is added.
  int? _noteId;

  bool get _isNew => _noteId == null;

  // Snapshot taken right after load, compared against the live fields to tell
  // whether the user has actually changed anything (BUG-005: skip the network
  // write entirely when they open a note and back out untouched).
  late String _initialSnapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final n = widget.note;
    // Seed a brand-new note from a chosen template (blank template = empty note).
    final t = n == null ? widget.template : null;
    _noteId = n?.id;
    // Content shared from another app seeds a brand-new note's body.
    final shared = (n == null && t == null) ? widget.initialText : null;
    _title = TextEditingController(text: n?.title ?? t?.title ?? '');
    _body = TextEditingController(text: n?.body ?? t?.body ?? shared ?? '');
    _type = n?.type ?? t?.type ?? 'note';
    _items = n != null && n.items.isNotEmpty
        ? n.items.map((e) => ChecklistItem(text: e.text, done: e.done)).toList()
        : (t != null && t.items.isNotEmpty
            ? t.items.map((e) => ChecklistItem(text: e)).toList()
            : [ChecklistItem(text: '')]);
    // Keep-style grouping: unchecked items live on top, checked ones sink to a
    // "Completed" section. Partition once on open (stable — List.sort isn't) so
    // the "unchecked prefix" invariant holds for the rest of the session.
    _items = [..._items.where((i) => !i.done), ..._items.where((i) => i.done)];
    _color = n?.color ?? 'default';
    _labels = List<String>.from(n?.labels ?? []);
    _pinned = n?.pinned ?? false;
    if (n?.reminderAt != null) {
      try { _reminder = DateTime.parse(n!.reminderAt!).toLocal(); } catch (_) {}
    }
    _repeat = n?.repeat ?? 'none';
    _buildItemControllers();
    _initialSnapshot = _snapshot();
    // A template- or share-seeded note should persist even if the user backs
    // out without further typing (BUG-005's untouched-note skip is only for
    // empty new notes).
    if ((t != null && !t.isBlank) || (shared != null && shared.trim().isNotEmpty)) {
      _initialSnapshot = 'template-seed-sentinel';
    }
    if (!_isNew) _loadAttachments();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _title.dispose();
    _body.dispose();
    _labelInput.dispose();
    _disposeItemControllers();
    super.dispose();
  }

  // Backgrounding is the real-world precursor to an OS-level app kill (low
  // memory, swipe-away) — flush a dirty draft to the server here so it isn't
  // lost with the process (BUG-010). Best-effort and silent: the screen isn't
  // visible while this runs, so there's no one to show an error to, and the
  // explicit Save/back path remains the source of truth for user-facing failures.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _autosaveIfDirty();
    }
  }

  // Cheap serialization of every persisted field — used both to detect real
  // edits (BUG-005) and to know when a background autosave has new work to do
  // (BUG-010).
  String _snapshot() {
    _syncItems();
    final items = _items.map((e) => '${e.text}#${e.done}').join('|');
    return [_title.text, _body.text, _type, items, _color, _labels.join('|'), _pinned, _reminder?.toIso8601String(), _repeat]
        .join('~');
  }

  bool get _dirty => _snapshot() != _initialSnapshot;

  Future<void> _autosaveIfDirty() async {
    if (_saving || !_dirty) return;
    if (_isNew && _isEmptyDraft) return;
    try {
      await _persist(_payload());
      _initialSnapshot = _snapshot();
    } catch (_) {/* best-effort — the explicit Save/back path will retry */}
  }

  void _buildItemControllers() {
    for (final it in _items) {
      _itemCtrls.add(TextEditingController(text: it.text));
      _itemNodes.add(FocusNode());
    }
  }

  void _disposeItemControllers() {
    for (final c in _itemCtrls) { c.dispose(); }
    for (final n in _itemNodes) { n.dispose(); }
    _itemCtrls.clear();
    _itemNodes.clear();
  }

  // Pull the latest text out of the controllers into the model before save/AI.
  void _syncItems() {
    for (var i = 0; i < _items.length && i < _itemCtrls.length; i++) {
      _items[i].text = _itemCtrls[i].text;
    }
  }

  void _addItemAt(int index) {
    _syncItems();
    setState(() {
      _items.insert(index, ChecklistItem(text: ''));
      _itemCtrls.insert(index, TextEditingController());
      _itemNodes.insert(index, FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index < _itemNodes.length) _itemNodes[index].requestFocus();
    });
  }

  void _removeItem(int i) {
    _syncItems();
    setState(() {
      _items.removeAt(i);
      _itemCtrls.removeAt(i).dispose();
      _itemNodes.removeAt(i).dispose();
    });
  }

  // Drag-reorder: move an item (and its controller + focus node) to a new spot.
  // Only unchecked items are reorderable, and they form a list prefix, so the
  // display indices equal the real indices.
  void _onReorderItems(int oldIndex, int newIndex) {
    _syncItems();
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      _items.insert(newIndex, _items.removeAt(oldIndex));
      _itemCtrls.insert(newIndex, _itemCtrls.removeAt(oldIndex));
      _itemNodes.insert(newIndex, _itemNodes.removeAt(oldIndex));
    });
  }

  // Number of unchecked items = start of the "Completed" section.
  int get _uncheckedCount {
    final firstDone = _items.indexWhere((e) => e.done);
    return firstDone == -1 ? _items.length : firstDone;
  }

  // Check/uncheck an item and move it (with its controller + focus node) into
  // the right group: checked → bottom, unchecked → end of the active list.
  bool _showCompleted = true;
  void _toggleDone(int i) {
    _syncItems();
    setState(() {
      final item = _items[i];
      item.done = !item.done;
      final ctrl = _itemCtrls.removeAt(i);
      final node = _itemNodes.removeAt(i);
      _items.removeAt(i);
      final at = item.done ? _items.length : _uncheckedCount;
      _items.insert(at, item);
      _itemCtrls.insert(at, ctrl);
      _itemNodes.insert(at, node);
    });
  }

  // One checklist row: thin divider underneath (reference design), drag handle
  // for active items, strikethrough + faded ink once completed.
  Widget _itemRow(int i, {Key? key}) {
    final done = _items[i].done;
    return Container(
      key: key,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x14000000)))),
      child: Row(children: [
        if (!done)
          ReorderableDragStartListener(
            index: i,
            child: const Padding(
              padding: EdgeInsets.only(right: 2),
              child: Icon(Icons.drag_indicator, size: 20, color: Colors.black26),
            ),
          )
        else
          const SizedBox(width: 22),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: done ? 'Mark not done' : 'Mark done',
          icon: Icon(done ? Icons.check_box : Icons.check_box_outline_blank, color: done ? kBrand : Colors.black45),
          onPressed: () => _toggleDone(i),
        ),
        Expanded(
          child: TextField(
            controller: _itemCtrls[i],
            focusNode: _itemNodes[i],
            onChanged: (v) => _items[i].text = v,
            textInputAction: done ? TextInputAction.done : TextInputAction.next,
            onSubmitted: done ? null : (_) => _addItemAt(i + 1), // Enter → new line below, focused
            decoration: const InputDecoration(hintText: 'List item', hintStyle: TextStyle(color: _inkFaint), border: InputBorder.none, isDense: true),
            style: TextStyle(
              color: done ? Colors.black38 : _ink,
              decoration: done ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        IconButton(visualDensity: VisualDensity.compact, tooltip: 'Remove item', icon: const Icon(Icons.close, size: 18, color: Colors.black38), onPressed: () => _removeItem(i)),
      ]),
    );
  }

  String _stripBullet(String s) =>
      s.replaceFirst(RegExp(r'^\s*([-*•]|\[[ xX]?\])\s+'), '').trim();

  // Toggle between text note and checklist WITHOUT losing content:
  // note -> checklist splits the body into one item per line;
  // checklist -> note joins the items back into the body.
  void _convertType() {
    if (_type == 'note') {
      final lines = _body.text
          .split('\n')
          .map(_stripBullet)
          .where((l) => l.isNotEmpty)
          .toList();
      _disposeItemControllers();
      _items = lines.isEmpty ? [ChecklistItem(text: '')] : lines.map((t) => ChecklistItem(text: t)).toList();
      _buildItemControllers();
      setState(() => _type = 'checklist');
    } else {
      _syncItems();
      final joined = _items.where((i) => i.text.trim().isNotEmpty).map((i) => i.text.trim()).join('\n');
      _body.text = joined;
      setState(() => _type = 'note');
    }
  }

  // Make sure the note exists on the server (so attachments can reference it).
  // Called automatically the first time an image/drawing/file is added to a new
  // note, so the user never has to "Save first". A single in-flight create is
  // shared: if two attach actions race (e.g. a second chip tapped while a picker
  // is open), both await the same create instead of making duplicate notes.
  //
  // Offline-first (qa-audit REMEDIATION_PLAN.md): _createNoteNow() succeeds
  // even without connectivity, handing back a negative temp id so the rest of
  // the note (title/body/checklist/labels) still "saves" instantly. Attachment
  // bytes aren't queued in this scope though — a temp id means the note hasn't
  // reached the server yet, so uploading to it would fail confusingly. Gate it
  // here, once, instead of in every _add*() call site.
  Future<bool>? _ensureInFlight;
  Future<bool> _ensureNoteId() async {
    if (_noteId != null && _noteId! > 0) return true;
    final ok = _noteId == null
        ? await (_ensureInFlight ??= _createNoteNow().whenComplete(() => _ensureInFlight = null))
        : true;
    if (ok && (_noteId == null || _noteId! < 0)) {
      _snack('This note hasn\'t synced yet — connect to the internet to add attachments.');
      return false;
    }
    return ok;
  }

  Future<bool> _createNoteNow() async {
    if (_noteId != null) return true;
    _syncItems();
    final items = _items.where((i) => i.text.trim().isNotEmpty).map((e) => e.toJson()).toList();
    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'type': _type,
      'body': _type == 'note' ? _body.text.trim() : '',
      'items': _type == 'checklist' ? items : <dynamic>[],
      'color': _color,
      'labels': _labels,
      'pinned': _pinned,
      'repeat': _repeat,
    };
    if (_reminder != null) payload['reminderAt'] = _reminder!.toUtc().toIso8601String();
    try {
      final id = await Api.instance.createNoteReturningId(payload);
      if (id == null) { _snack('Could not save note'); return false; }
      setState(() => _noteId = id);
      return true;
    } catch (e) { _snack(friendlyError(e)); return false; }
  }

  Future<void> _loadAttachments() async {
    try {
      final list = await Api.instance.listAttachments(_noteId!);
      if (mounted) setState(() => _attachments = list);
    } catch (_) {}
  }

  Future<void> _addImage({required bool ocr}) async {
    try {
      final XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) { _snack('Image is over 8 MB'); return; }
      if (!await _ensureNoteId()) return;
      await _upload(picked.name, _mimeForName(picked.name, fallback: 'image/jpeg'), base64Encode(bytes), ocr: ocr);
    } catch (e) { _snack(friendlyError(e)); }
  }

  Future<void> _addDrawing() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const DrawScreen()));
    if (bytes == null || bytes.isEmpty) return;
    if (!await _ensureNoteId()) return;
    await _upload('drawing-${DateTime.now().millisecondsSinceEpoch}.png', 'image/png', base64Encode(bytes), ocr: false);
  }

  Future<void> _addFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final bytes = f.bytes;
      if (bytes == null) { _snack('Could not read file'); return; }
      if (bytes.length > 8 * 1024 * 1024) { _snack('File is over 8 MB'); return; }
      if (!await _ensureNoteId()) return;
      await _upload(f.name, _mimeForName(f.name), base64Encode(bytes), ocr: false);
    } catch (e) { _snack(friendlyError(e)); }
  }

  // Voice note: record a memo, then upload it as an audio attachment. Reuses the
  // existing attachment pipeline (no backend change — audio is just a file).
  Future<void> _addVoice() async {
    try {
      final path = await recordVoiceSheet(context);
      if (path == null || !mounted) return;
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) { _snack('Recording was empty'); return; }
      if (bytes.length > 8 * 1024 * 1024) { _snack('Recording is over 8 MB'); return; }
      if (!await _ensureNoteId()) return;
      final name = 'Voice ${DateFormat('MMM d, h:mm a').format(DateTime.now())}.m4a';
      await _upload(name, 'audio/mp4', base64Encode(bytes), ocr: false);
      try { await File(path).delete(); } catch (_) {} // temp recording no longer needed
    } catch (e) { _snack(friendlyError(e)); }
  }

  // Transcribe a voice-note attachment to text (server Whisper) and drop the
  // result into the note — as a new checklist item, or appended to the body.
  Future<void> _transcribe(Attachment a) async {
    setState(() => _transcribing = a.id);
    try {
      final code = LocaleController.locale.value.languageCode;
      final text = await Api.instance.transcribeAttachment(a.id, language: code);
      if (!mounted) return;
      if (text.trim().isEmpty) { _snack(tr('no_speech')); return; }
      setState(() {
        if (_type == 'checklist') {
          _syncItems();
          _items.add(ChecklistItem(text: text.trim()));
          _disposeItemControllers();
          _buildItemControllers();
        } else {
          final sep = _body.text.trim().isEmpty ? '' : '\n\n';
          _body.text = '${_body.text}$sep${text.trim()}';
        }
      });
      _snack(tr('transcribed'));
    } catch (e) {
      if (mounted) _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _transcribing = null);
    }
  }

  // On-device voice typing (Keep parity): dictate straight into the note using
  // the phone's own speech recognizer — no API key, no cost, offline where the
  // device supports it. Text streams into the note LIVE as you speak, and it
  // keeps listening across pauses (multi-sentence) until you tap Stop.
  Future<void> _voiceType() async {
    final speech = SpeechToText();
    final code = LocaleController.locale.value.languageCode;
    final bool checklist = _type == 'checklist';

    // Dictate into a fresh checklist item, or append to the note body. `base`
    // is the text that existed before dictation; committed = finalised sessions.
    int? itemIndex;
    String base = '';
    if (checklist) {
      _syncItems();
      setState(() => _items.add(ChecklistItem(text: '')));
      itemIndex = _items.length - 1;
      _disposeItemControllers();
      _buildItemControllers();
    } else {
      base = _body.text;
    }
    // Text from all finished dictation sessions; `current` = the in-progress
    // session's latest partial. The note always shows committed + current, so a
    // new sentence APPENDS after earlier ones instead of replacing them.
    var committed = '';
    var current = '';
    var active = true;

    // Live-write (finished sessions + the in-progress partial) into the note.
    void render() {
      final live = current.trim();
      final joined = committed.isEmpty ? live : (live.isEmpty ? committed : '$committed $live');
      if (!mounted) return;
      final idx = itemIndex;
      setState(() {
        if (checklist && idx != null && idx < _itemCtrls.length) {
          _itemCtrls[idx].text = joined;
          _items[idx].text = joined;
        } else {
          final sep = (base.isEmpty || base.endsWith(' ') || base.endsWith('\n')) ? '' : ' ';
          _body.text = joined.isEmpty ? base : '$base$sep$joined';
          _body.selection = TextSelection.collapsed(offset: _body.text.length);
        }
      });
    }

    // Fold the finished session's words into `committed`. Called on every final
    // result AND when a session ends (many Android recognizers never flag a
    // final result on a pause), so nothing spoken is ever dropped or overwritten.
    void commitCurrent() {
      final t = current.trim();
      if (t.isNotEmpty) committed = committed.isEmpty ? t : '$committed $t';
      current = '';
    }

    Future<void> startSession() async {
      if (!active) return;
      try {
        await speech.listen(
          localeId: code,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 8),
          onResult: (r) {
            current = r.recognizedWords;
            render();
            if (r.finalResult) commitCurrent();
          },
        );
      } catch (_) {}
    }

    bool available = false;
    try {
      available = await speech.initialize(
        onError: (_) {},
        // A session ends on silence/timeout — restart while still dictating so
        // more than one sentence keeps getting appended.
        onStatus: (status) {
          if (active && !speech.isListening && (status == 'done' || status == 'notListening')) {
            // Commit this session's words BEFORE restarting so the next sentence
            // appends after them (don't rely on a final-result flag that may
            // never arrive on a pause).
            commitCurrent();
            startSession();
          }
        },
      );
    } catch (_) {}
    if (!available) {
      final idx = itemIndex;
      if (checklist && idx != null) { setState(() => _items.removeAt(idx)); _disposeItemControllers(); _buildItemControllers(); }
      if (mounted) _snack(tr('speech_unavailable'));
      return;
    }
    if (!mounted) { active = false; try { await speech.stop(); } catch (_) {} return; }

    await startSession();
    if (!mounted) { active = false; try { await speech.stop(); } catch (_) {} return; }

    // A slim "listening" sheet — the text appears in the note above it, live.
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.mic, size: 40, color: kBrand),
          const SizedBox(height: 10),
          Text(tr('listening'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary)),
          const SizedBox(height: 4),
          Text(tr('voice_typing_hint'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.stop), label: Text(tr('stop'))),
        ]),
      )),
    );

    active = false;
    try { await speech.stop(); } catch (_) {}
    // Drop an empty dictation item if nothing was said.
    final endIdx = itemIndex;
    if (checklist && endIdx != null && mounted && _items[endIdx].text.trim().isEmpty) {
      setState(() => _items.removeAt(endIdx));
      _disposeItemControllers();
      _buildItemControllers();
    }
  }

  Future<void> _upload(String name, String type, String b64, {required bool ocr}) async {
    setState(() => _uploading = true);
    try {
      final r = await Api.instance.addAttachment(
        noteId: _noteId!, fileName: name, fileType: type, base64Data: b64, ocr: ocr,
      );
      final ocrText = (r['ocrText'] ?? '').toString();
      final ocrError = (r['ocrError'] ?? '').toString();
      if (ocr && ocrText.isEmpty && ocrError.isNotEmpty) {
        _snack(ocrError); // e.g. unsupported format / vision API error — never fail silently
      }
      if (ocr && ocrText.isNotEmpty && mounted) {
        setState(() {
          // OCR output goes into the text body. If this was a checklist, first
          // fold the items into the body so no checklist content is lost.
          if (_type == 'checklist') {
            _syncItems();
            final joined = _items.where((i) => i.text.trim().isNotEmpty).map((i) => i.text.trim()).join('\n');
            _body.text = joined;
            _type = 'note';
          }
          _body.text = (_body.text.trim().isEmpty ? '' : '${_body.text.trim()}\n\n') + ocrText;
        });
        _snack('Text extracted from image');
      }
      await _loadAttachments();
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteAttachment(Attachment a) async {
    // Deleting an attachment is permanent — confirm first (P10).
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Remove attachment?'),
      content: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
      ]));
    if (ok != true) return;
    try {
      await Api.instance.deleteAttachment(a.id);
      await _loadAttachments();
    } catch (e) { _snack(friendlyError(e)); }
  }

  String _mimeForName(String name, {String fallback = 'application/octet-stream'}) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif',
      'webp': 'image/webp', 'heic': 'image/heic', 'pdf': 'application/pdf', 'txt': 'text/plain',
      'doc': 'application/msword', 'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    return map[ext] ?? fallback;
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // Builds the save payload from live state. Shared by the explicit Save/back
  // path and the background autosave hook so both persist identically.
  Map<String, dynamic> _payload() {
    _syncItems();
    final items = _items.where((i) => i.text.trim().isNotEmpty).map((e) => e.toJson()).toList();
    return <String, dynamic>{
      'title': _title.text.trim(),
      'type': _type,
      'body': _type == 'note' ? _body.text.trim() : '',
      'items': _type == 'checklist' ? items : <dynamic>[],
      'color': _color,
      'labels': _labels,
      'pinned': _pinned,
      'repeat': _repeat,
    };
  }

  bool get _isEmptyDraft {
    final p = _payload();
    return p['title'].toString().isEmpty && p['body'].toString().isEmpty && (p['items'] as List).isEmpty;
  }

  // Share this note's text to any other app via the OS share sheet. Shares the
  // live (possibly-unsaved) editor content rather than the last saved copy.
  Future<void> _shareNote() async {
    _syncItems();
    await shareEditorText(
      title: _title.text,
      body: _body.text,
      type: _type,
      items: _items,
      labels: _labels,
    );
  }

  // Version history (Keep parity): list this note's past content snapshots and
  // let the user restore any one. The current edits are saved first so nothing
  // in progress is lost, then the server-recorded versions are fetched.
  Future<void> _openVersionHistory() async {
    if (_noteId == null) return;
    // Flush any pending edit so the history reflects the latest content.
    try { if (_snapshot() != _initialSnapshot) { await _persist(_payload()); _initialSnapshot = _snapshot(); } } catch (_) {}
    List<NoteVersion> versions;
    try {
      versions = await Api.instance.noteVersions(_noteId!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      return;
    }
    if (!mounted) return;
    if (versions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('no_versions'))));
      return;
    }
    final fmt = DateFormat.yMMMd().add_jm();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              const Icon(Icons.history, size: 20),
              const SizedBox(width: 8),
              Text(tr('version_history'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: versions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final v = versions[i];
                final preview = v.preview.trim();
                return ListTile(
                  title: Text(v.createdAt != null ? fmt.format(v.createdAt!) : '#${v.id}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: preview.isEmpty ? null : Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: TextButton(
                    onPressed: () async { Navigator.pop(ctx); await _restoreVersion(v); },
                    child: Text(tr('restore'), style: const TextStyle(color: kBrandDark, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () async { Navigator.pop(ctx); await _restoreVersion(v); },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // Restore the note to [v] after a confirm, then reflect it in the open editor.
  Future<void> _restoreVersion(NoteVersion v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(tr('restore_version_q')),
        content: Text(tr('restore_version_sub')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text(tr('restore'))),
        ],
      ),
    );
    if (ok != true || !mounted || _noteId == null) return;
    try {
      await Api.instance.restoreNoteVersion(_noteId!, v.id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      return;
    }
    if (!mounted) return;
    _applyVersion(v);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('version_restored'))));
  }

  // Load a restored version's content into the live editor. The server already
  // holds this content (restore snapshotted the prior state first), so we align
  // _initialSnapshot to it — the editor is not "dirty" and won't re-save on back.
  void _applyVersion(NoteVersion v) {
    setState(() {
      _title.text = v.title;
      _body.text = v.body;
      _type = v.type == 'checklist' ? 'checklist' : 'note';
      _items = v.items.map((e) => ChecklistItem(text: e.text, done: e.done)).toList();
      _disposeItemControllers();
      _buildItemControllers();
    });
    _initialSnapshot = _snapshot();
  }

  // ── Collaboration ──
  // Owner-only sheet to add / list / remove collaborators on this note.
  Future<void> _openCollaborators() async {
    if (_noteId == null) return;
    // Persist any pending edit first so the note exists server-side to share.
    try { if (_snapshot() != _initialSnapshot) { await _persist(_payload()); _initialSnapshot = _snapshot(); } } catch (_) {}
    if (!mounted) return;
    final emailCtrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        List<Collaborator> people = [];
        bool loading = true;
        bool canEdit = true;
        bool busy = false;
        return StatefulBuilder(builder: (ctx, setSheet) {
          Future<void> refresh() async {
            try { people = await Api.instance.collaborators(_noteId!); } catch (_) {}
            if (ctx.mounted) setSheet(() => loading = false);
          }
          if (loading) refresh();
          Future<void> add() async {
            final email = emailCtrl.text.trim();
            if (email.isEmpty || busy) return;
            setSheet(() => busy = true);
            try {
              await Api.instance.shareNote(_noteId!, email, canEdit: canEdit);
              emailCtrl.clear();
              people = await Api.instance.collaborators(_noteId!);
            } catch (e) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(friendlyError(e))));
            } finally {
              if (ctx.mounted) setSheet(() => busy = false);
            }
          }
          Future<void> remove(Collaborator c) async {
            setSheet(() => busy = true);
            try { await Api.instance.unshareNote(_noteId!, c.userId); people = await Api.instance.collaborators(_noteId!); }
            catch (e) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(friendlyError(e)))); }
            finally { if (ctx.mounted) setSheet(() => busy = false); }
          }
          return SafeArea(child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.group_outlined, size: 20),
                const SizedBox(width: 8),
                Text(tr('collaborators'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: tr('add_by_email'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.mail_outline, size: 18),
                ),
                onSubmitted: (_) => add(),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(canEdit ? tr('can_edit') : tr('view_only'), style: const TextStyle(color: kTextMuted))),
                Switch(value: canEdit, onChanged: busy ? null : (v) => setSheet(() => canEdit = v)),
                const SizedBox(width: 4),
                FilledButton(onPressed: busy ? null : add, child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(tr('add'))),
              ]),
              const SizedBox(height: 8),
              if (loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
              else if (people.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(tr('no_collaborators'), style: const TextStyle(color: kTextMuted)))
              else Flexible(child: ListView(shrinkWrap: true, children: [
                for (final c in people)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(radius: 16, backgroundColor: kBrand.withOpacity(0.15), child: Text(c.label.substring(0, 1).toUpperCase(), style: const TextStyle(color: kBrandDark, fontWeight: FontWeight.bold))),
                    title: Text(c.label),
                    subtitle: Text(c.canEdit ? tr('can_edit') : tr('view_only'), style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(tooltip: tr('remove'), icon: const Icon(Icons.close, size: 18), onPressed: busy ? null : () => remove(c)),
                  ),
              ])),
            ]),
          ));
        });
      },
    );
    emailCtrl.dispose();
  }

  // Simple view-only screen for a note shared with me that I may not edit.
  Widget _buildReadOnlyView(BuildContext context) {
    final owner = (widget.note?.ownerName ?? '').trim();
    return Scaffold(
      backgroundColor: noteColor(_color),
      appBar: AppBar(
        backgroundColor: noteColor(_color),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(tooltip: tr('share'), icon: const Icon(Icons.share_outlined, color: Colors.black54), onPressed: _shareNote),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.visibility_outlined, size: 16, color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(child: Text(owner.isEmpty ? tr('view_only') : '${tr('view_only')} · ${tr('shared_by')} $owner',
                  style: const TextStyle(fontSize: 12, color: Colors.black54))),
            ]),
          ),
          if (_title.text.trim().isNotEmpty)
            SelectableText(_title.text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _ink, fontFamily: kDisplayFont)),
          const SizedBox(height: 10),
          if (_type == 'checklist')
            ..._items.where((i) => i.text.trim().isNotEmpty).map((i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(i.done ? Icons.check_box : Icons.check_box_outline_blank, size: 20, color: i.done ? kBrandDark : Colors.black38),
                const SizedBox(width: 8),
                Expanded(child: Text(i.text, style: TextStyle(fontSize: 15, color: _ink, decoration: i.done ? TextDecoration.lineThrough : null))),
              ]),
            ))
          else if (_body.text.trim().isNotEmpty)
            SelectableText(_body.text, style: const TextStyle(fontSize: 15, color: _ink, height: 1.35)),
        ],
      ),
    );
  }

  // Creates or updates the note and schedules/cancels its local reminder
  // notification. Shared by the explicit Save/back path and the background
  // autosave hook (BUG-005/BUG-010) — throws on failure, caller decides how
  // to handle it (show an error vs. fail silently in the background).
  Future<void> _persist(Map<String, dynamic> payload) async {
    if (_isNew) {
      // create() rejects a null reminder — only include it when set.
      if (_reminder != null) payload['reminderAt'] = _reminder!.toUtc().toIso8601String();
      _noteId = await Api.instance.createNoteReturningId(payload);
    } else {
      // update() accepts null to clear an existing reminder.
      payload['reminderAt'] = _reminder?.toUtc().toIso8601String();
      await Api.instance.updateNote({'id': _noteId!, ...payload});
    }
    // Schedule / clear the local reminder notification for this note.
    if (_noteId != null) {
      if (_reminder != null) {
        await Notifications.instance.schedule(
          noteId: _noteId!,
          title: _title.text.trim(),
          body: _type == 'note' ? _body.text.trim() : _items.where((i) => i.text.trim().isNotEmpty).map((i) => i.text.trim()).join(', '),
          when: _reminder!,
          repeat: _repeat,
        );
      } else {
        await Notifications.instance.cancel(_noteId!);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final payload = _payload();
    try {
      if (_isNew && _isEmptyDraft) { if (mounted) Navigator.pop(context, false); return; }
      await _persist(payload);
      _initialSnapshot = _snapshot();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _delete() async {
    if (_isNew) { Navigator.pop(context, false); return; }
    try {
      await Notifications.instance.cancel(_noteId!); // drop any pending reminder
      await Api.instance.trashNote(_noteId!); // move to Trash (restorable)
      if (mounted) Navigator.pop(context, true);
    } catch (e) { _snack(friendlyError(e)); }
  }

  // System back = Save (Google Keep behavior). Without this, back silently threw
  // away edits — and hid notes that were auto-created by the first attachment.
  //
  // _save() already owns every navigation decision: it pops with true on a
  // successful save, pops with false for a never-touched empty new note, and
  // — critically — does NOT pop when the save throws (it shows an error and
  // stays put so the edit isn't lost). _onBack must not second-guess that:
  // an earlier version popped unconditionally after awaiting _save(), which
  // discarded the user's edit whenever the save failed (e.g. offline).
  //
  // BUG-005: skip the network round-trip entirely when nothing actually
  // changed — opening a note and backing straight out shouldn't issue a write.
  Future<void> _onBack() async {
    if (_saving) return;
    if (!_dirty) { if (mounted) Navigator.pop(context, false); return; }
    await _save();
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _reminder ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 3650)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_reminder ?? now));
    if (t == null || !mounted) return;
    final when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    // A reminder in the past would never fire — guard it (P20).
    if (!when.isAfter(DateTime.now())) { _snack('Pick a time in the future.'); return; }
    setState(() => _reminder = when);
  }

  void _addLabel() {
    final v = _labelInput.text.trim();
    if (v.isNotEmpty && !_labels.contains(v)) setState(() => _labels.add(v));
    _labelInput.clear();
  }

  String? _aiBusy;
  String _aiContent() => (_type == 'note'
      ? _body.text
      : _items.where((i) => i.text.trim().isNotEmpty).map((i) => '- ${i.text}').join('\n')).trim();

  Future<void> _doAI(String action) async {
    _syncItems();
    final content = _aiContent();
    if (content.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write something first.'))); return; }
    setState(() => _aiBusy = action);
    try {
      final text = (await Api.instance.aiAction(action, content)).trim();
      if (text.isEmpty || !mounted) return;
      setState(() {
        if (action == 'title') { _title.text = text; }
        else if (action == 'clean') { _type = 'note'; _body.text = text; } // cleaned version of the checklist content
        else {
          // Summary/keypoints append to the body. If this was a checklist, fold
          // the items into the body FIRST so they aren't lost on save.
          if (_type == 'checklist') {
            final joined = _items.where((i) => i.text.trim().isNotEmpty).map((i) => i.text.trim()).join('\n');
            _body.text = joined;
            _type = 'note';
          }
          _body.text = (_body.text.trim().isEmpty ? '' : '${_body.text.trim()}\n\n') + text;
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _aiBusy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) return _buildReadOnlyView(context);
    final isSharedWithMe = widget.note?.shared ?? false;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Ctrl+S saves (hardware keyboards: tablets / DeX / Chromebook / desktop).
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () { if (!_saving) _save(); },
      },
      child: PopScope(
      canPop: false, // back = auto-save then exit (never silently discard edits)
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _onBack(); },
      child: Scaffold(
      backgroundColor: noteColor(_color),
      appBar: AppBar(
        backgroundColor: noteColor(_color),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(tooltip: _pinned ? 'Unpin' : 'Pin', icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined, color: _pinned ? kBrandDark : Colors.black54), onPressed: () => setState(() => _pinned = !_pinned)),
          IconButton(tooltip: tr('share'), icon: const Icon(Icons.share_outlined, color: Colors.black54), onPressed: _shareNote),
          // Collaborators + Delete + version history are OWNER-only surfaces —
          // hidden on a note that was shared with me.
          if (!_isNew && !isSharedWithMe)
            IconButton(tooltip: tr('collaborators'), icon: const Icon(Icons.person_add_alt, color: Colors.black54), onPressed: _openCollaborators),
          if (!isSharedWithMe)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline, color: Colors.black54), onPressed: _delete),
          if (!_isNew && !isSharedWithMe)
            IconButton(tooltip: tr('version_history'), icon: const Icon(Icons.history, color: Colors.black54), onPressed: _openVersionHistory),
          TextButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(tr('save'), style: const TextStyle(color: kBrandDark, fontWeight: FontWeight.bold))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            maxLines: null,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _ink, fontFamily: kDisplayFont, height: 1.25),
            decoration: const InputDecoration(hintText: 'Title', hintStyle: TextStyle(color: _inkFaint, fontWeight: FontWeight.w600), border: InputBorder.none),
          ),
          const SizedBox(height: 8),
          if (_type == 'note')
            TextField(
              controller: _body,
              maxLines: null,
              minLines: 6,
              style: const TextStyle(fontSize: 15, color: _ink, height: 1.35),
              decoration: const InputDecoration(hintText: 'Take a note…', hintStyle: TextStyle(color: _inkFaint), border: InputBorder.none),
            )
          else
            Column(children: [
              // Active items — drag the ⠿ handle to reorder.
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _uncheckedCount,
                onReorder: _onReorderItems,
                itemBuilder: (context, i) => _itemRow(i, key: ValueKey(_itemNodes[i])),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(onPressed: () => _addItemAt(_uncheckedCount), icon: const Icon(Icons.add, size: 18), label: const Text('Add item'), style: TextButton.styleFrom(foregroundColor: Colors.black54)),
              ),
              // Completed section — checked items sink here (tap header to hide).
              if (_items.length > _uncheckedCount) ...[
                InkWell(
                  onTap: () => setState(() => _showCompleted = !_showCompleted),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Icon(_showCompleted ? Icons.expand_more : Icons.chevron_right, size: 20, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text('Completed (${_items.length - _uncheckedCount})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                    ]),
                  ),
                ),
                if (_showCompleted)
                  for (var i = _uncheckedCount; i < _items.length; i++) _itemRow(i),
              ],
            ]),
          // Fixed dark hairline: the theme divider goes near-white in dark mode,
          // which is invisible on the always-light pastel note background (P14).
          const Divider(height: 28, color: Color(0x1F000000)),
          // AI actions
          Row(children: [
            const Icon(Icons.auto_awesome, size: 16, color: kBrand),
            const SizedBox(width: 6),
            Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in const [['title', 'Title'], ['summary', 'Summarize'], ['clean', 'Clean up'], ['keypoints', 'Key points']])
                ActionChip(
                  avatar: _aiBusy == a[0] ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: kBrandDark)) : null,
                  label: Text(a[1], style: TextStyle(fontSize: 11, color: _aiBusy == null || _aiBusy == a[0] ? kBrandDark : Colors.black26)),
                  backgroundColor: const Color(0xFFE3F2FD),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  onPressed: _aiBusy == null ? () => _doAI(a[0]) : null, // visibly disabled while one runs
                ),
            ])),
          ]),
          const SizedBox(height: 12),
          // Attachments (image / drawing / file + OCR). Tapping any of these on a
          // brand-new note auto-saves it first, so no "Save first" step is needed.
          ...[
            Row(children: [
              const Icon(Icons.attach_file, size: 16, color: Colors.black54),
              const SizedBox(width: 6),
              Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
                ActionChip(
                  avatar: const Icon(Icons.image_outlined, size: 16, color: Colors.black54),
                  label: const Text('Image', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: _uploading ? null : () => _addImage(ocr: false),
                ),
                ActionChip(
                  avatar: const Icon(Icons.document_scanner_outlined, size: 16, color: kBrandDark),
                  label: const Text('Image + OCR', style: TextStyle(fontSize: 11, color: kBrandDark)),
                  backgroundColor: const Color(0xFFE3F2FD),
                  visualDensity: VisualDensity.compact,
                  onPressed: _uploading ? null : () => _addImage(ocr: true),
                ),
                ActionChip(
                  avatar: const Icon(Icons.insert_drive_file_outlined, size: 16, color: Colors.black54),
                  label: const Text('File', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: _uploading ? null : _addFile,
                ),
                ActionChip(
                  avatar: const Icon(Icons.draw_outlined, size: 16, color: Colors.black54),
                  label: const Text('Draw', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: _uploading ? null : _addDrawing,
                ),
                ActionChip(
                  avatar: const Icon(Icons.mic_none, size: 16, color: Colors.black54),
                  label: Text(tr('voice'), style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: _uploading ? null : _addVoice,
                ),
                ActionChip(
                  avatar: const Icon(Icons.keyboard_voice_outlined, size: 16, color: kBrandDark),
                  label: Text(tr('voice_typing'), style: const TextStyle(fontSize: 11, color: kBrandDark)),
                  backgroundColor: const Color(0xFFE3F2FD),
                  visualDensity: VisualDensity.compact,
                  onPressed: _uploading ? null : _voiceType,
                ),
                if (_uploading) const Padding(padding: EdgeInsets.all(6), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
              ])),
            ]),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in _attachments)
                  Stack(clipBehavior: Clip.none, children: [
                    if (a.isImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(imageUrl: Api.instance.absoluteUrl(a.fileUrl), width: 72, height: 72, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(width: 72, height: 72, color: Colors.black12, child: const Icon(Icons.broken_image, color: Colors.black38))),
                      )
                    else if (a.isAudio)
                      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AudioChip(url: Api.instance.absoluteUrl(a.fileUrl), label: a.fileName),
                        TextButton.icon(
                          onPressed: _transcribing == a.id ? null : () => _transcribe(a),
                          icon: _transcribing == a.id
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.subtitles_outlined, size: 16),
                          label: Text(tr('transcribe'), style: const TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6), foregroundColor: kBrandDark),
                        ),
                      ])
                    else
                      Container(
                        width: 96, height: 72, padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.insert_drive_file_outlined, color: Colors.black45),
                          const SizedBox(height: 2),
                          Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.black54)),
                        ]),
                      ),
                    Positioned(
                      top: -8, right: -8,
                      child: Tooltip(
                        message: 'Remove attachment',
                        child: GestureDetector(
                          onTap: () => _deleteAttachment(a),
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.cancel, size: 18, color: Colors.black45),
                          ),
                        ),
                      ),
                    ),
                  ]),
              ]),
            ],
            const SizedBox(height: 12),
          ],
          // Labels
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final l in _labels)
              Chip(
                label: Text(l, style: const TextStyle(fontSize: 12, color: _ink)),
                onDeleted: () => setState(() => _labels.remove(l)),
                deleteIconColor: Colors.black45,
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.white.withOpacity(0.7),
              ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _labelInput,
                onSubmitted: (_) => _addLabel(),
                style: const TextStyle(color: _ink, fontSize: 14),
                decoration: const InputDecoration(hintText: 'Add label', hintStyle: TextStyle(color: _inkFaint), isDense: true, prefixIcon: Icon(Icons.label_outline, size: 16, color: Colors.black45)),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          // Reminder
          Row(children: [
            const Icon(Icons.notifications_none, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            if (_reminder == null)
              TextButton(onPressed: _pickReminder, child: Text(tr('add_reminder')))
            else ...[
              Flexible(child: GestureDetector(
                onTap: _pickReminder,
                child: Text(DateFormat('MMM d, yyyy • h:mm a').format(_reminder!), style: const TextStyle(fontSize: 13, color: _ink)),
              )),
              IconButton(tooltip: tr('remove_reminder'), icon: const Icon(Icons.close, size: 16, color: Colors.black54), onPressed: () => setState(() { _reminder = null; _repeat = 'none'; })),
            ],
          ]),
          // Repeat — only meaningful once a reminder time is set.
          if (_reminder != null)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2),
              child: Row(children: [
                const Icon(Icons.repeat, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _repeat,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(fontSize: 13, color: _ink),
                  onChanged: (v) => setState(() => _repeat = v ?? 'none'),
                  items: [
                    DropdownMenuItem(value: 'none', child: Text(tr('repeat_none'))),
                    DropdownMenuItem(value: 'daily', child: Text(tr('repeat_daily'))),
                    DropdownMenuItem(value: 'weekly', child: Text(tr('repeat_weekly'))),
                    DropdownMenuItem(value: 'monthly', child: Text(tr('repeat_monthly'))),
                  ],
                ),
              ]),
            ),
          const SizedBox(height: 16),
          // Type toggle
          Row(children: [
            const Icon(Icons.tune, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _convertType,
              child: Text(_type == 'note' ? 'Convert to checklist' : 'Convert to text'),
            ),
          ]),
          const SizedBox(height: 8),
          // Color palette
          const Text('Color', style: TextStyle(fontSize: 12, color: Colors.black45)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final key in kColorKeys)
              Semantics(
                label: '$key note color',
                selected: _color == key,
                button: true,
                child: GestureDetector(
                  onTap: () => setState(() => _color = key),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: noteColor(key),
                      shape: BoxShape.circle,
                      border: Border.all(color: _color == key ? kBrand : Colors.black26, width: _color == key ? 3 : 1),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    )));
  }
}
