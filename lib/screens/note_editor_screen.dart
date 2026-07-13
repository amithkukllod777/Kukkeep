import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../api.dart';
import '../models.dart';
import '../note_colors.dart';
import '../notifications.dart';
import 'draw_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});
  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _title;
  late TextEditingController _body;
  late String _type;
  late List<ChecklistItem> _items;
  late String _color;
  late List<String> _labels;
  DateTime? _reminder;
  late bool _pinned;
  final _labelInput = TextEditingController();
  bool _saving = false;

  // Persistent per-item controllers/focus nodes so the checklist keeps its text,
  // cursor and focus across rebuilds (and Enter can move focus to the new line).
  final List<TextEditingController> _itemCtrls = [];
  final List<FocusNode> _itemNodes = [];

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

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _noteId = n?.id;
    _title = TextEditingController(text: n?.title ?? '');
    _body = TextEditingController(text: n?.body ?? '');
    _type = n?.type ?? 'note';
    _items = n != null && n.items.isNotEmpty
        ? n.items.map((e) => ChecklistItem(text: e.text, done: e.done)).toList()
        : [ChecklistItem(text: '')];
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
    _buildItemControllers();
    if (!_isNew) _loadAttachments();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _labelInput.dispose();
    _disposeItemControllers();
    super.dispose();
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
        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18, color: Colors.black38), onPressed: () => _removeItem(i)),
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
  Future<bool>? _ensureInFlight;
  Future<bool> _ensureNoteId() {
    if (_noteId != null) return Future.value(true);
    return _ensureInFlight ??= _createNoteNow().whenComplete(() => _ensureInFlight = null);
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
    };
    if (_reminder != null) payload['reminderAt'] = _reminder!.toUtc().toIso8601String();
    try {
      final id = await Api.instance.createNoteReturningId(payload);
      if (id == null) { _snack('Could not save note'); return false; }
      setState(() => _noteId = id);
      return true;
    } catch (e) { _snack(e.toString()); return false; }
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
    } catch (e) { _snack(e.toString()); }
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
    } catch (e) { _snack(e.toString()); }
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
      if (ocr && ocrText.isNotEmpty) {
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
      _snack(e.toString());
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
    } catch (e) { _snack(e.toString()); }
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

  Future<void> _save() async {
    _syncItems();
    setState(() => _saving = true);
    final items = _items.where((i) => i.text.trim().isNotEmpty).map((e) => e.toJson()).toList();
    final payload = <String, dynamic>{
      'title': _title.text.trim(),
      'type': _type,
      'body': _type == 'note' ? _body.text.trim() : '',
      'items': _type == 'checklist' ? items : <dynamic>[],
      'color': _color,
      'labels': _labels,
      'pinned': _pinned,
    };
    try {
      if (_isNew) {
        final empty = payload['title'].toString().isEmpty && payload['body'].toString().isEmpty && items.isEmpty;
        if (empty) { if (mounted) Navigator.pop(context, false); return; }
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
          );
        } else {
          await Notifications.instance.cancel(_noteId!);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _delete() async {
    if (_isNew) { Navigator.pop(context, false); return; }
    try {
      await Notifications.instance.cancel(_noteId!); // drop any pending reminder
      await Api.instance.trashNote(_noteId!); // move to Trash (restorable)
      if (mounted) Navigator.pop(context, true);
    } catch (e) { _snack(e.toString()); }
  }

  // System back = Save (Google Keep behavior). Without this, back silently threw
  // away edits — and hid notes that were auto-created by the first attachment.
  Future<void> _onBack() async {
    if (_saving) return;
    await _save(); // pops with true after saving; pops false for an empty new note
    // If save failed (snackbar shown, still mounted), let the user decide —
    // they can retry, or discard via back again within the error state.
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.pop(context, _noteId != null);
    }
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _reminder ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 3650)));
    if (d == null) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_reminder ?? now));
    if (t == null) return;
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
      if (text.isEmpty) return;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _aiBusy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // back = auto-save then exit (never silently discard edits)
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _onBack(); },
      child: Scaffold(
      backgroundColor: noteColor(_color),
      appBar: AppBar(
        backgroundColor: noteColor(_color),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined, color: _pinned ? kBrandDark : Colors.black54), onPressed: () => setState(() => _pinned = !_pinned)),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.black54), onPressed: _delete),
          TextButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save', style: TextStyle(color: kBrandDark, fontWeight: FontWeight.bold))),
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
                        child: Image.network(Api.instance.absoluteUrl(a.fileUrl), width: 72, height: 72, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 72, height: 72, color: Colors.black12, child: const Icon(Icons.broken_image, color: Colors.black38))),
                      )
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
                      child: GestureDetector(
                        onTap: () => _deleteAttachment(a),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.cancel, size: 18, color: Colors.black45),
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
              TextButton(onPressed: _pickReminder, child: const Text('Add reminder'))
            else ...[
              Text(DateFormat('MMM d, yyyy • h:mm a').format(_reminder!), style: const TextStyle(fontSize: 13, color: _ink)),
              IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.black54), onPressed: () => setState(() => _reminder = null)),
            ],
          ]),
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
              GestureDetector(
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
          ]),
          const SizedBox(height: 40),
        ],
      ),
    ));
  }
}
