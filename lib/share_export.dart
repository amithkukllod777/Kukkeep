import 'dart:convert';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'models.dart';

/// Sharing + export helpers (Google-Keep parity: "share note to other apps"
/// and "export"). All go through the OS share sheet via share_plus, so the
/// user can send text to any app or save an export file to Drive/Files.

/// Render a single note as human-readable plain text: title, then the body for
/// a text note or `[x]`/`[ ]` lines for a checklist, with #labels appended.
String noteToPlainText(Note n) => _composeText(
      title: n.title,
      body: n.body,
      type: n.type,
      items: n.items,
      labels: n.labels,
    );

/// Compose share text from raw fields (used by the editor, which holds live,
/// possibly-unsaved edits rather than a saved [Note]).
String _composeText({
  required String title,
  required String body,
  required String type,
  required List<ChecklistItem> items,
  required List<String> labels,
}) {
  final b = StringBuffer();
  if (title.trim().isNotEmpty) b.writeln(title.trim());
  if (type == 'checklist') {
    for (final it in items) {
      if (it.text.trim().isEmpty) continue;
      b.writeln('${it.done ? '[x]' : '[ ]'} ${it.text.trim()}');
    }
  } else if (body.trim().isNotEmpty) {
    b.writeln(body.trim());
  }
  if (labels.isNotEmpty) {
    b.writeln();
    b.writeln(labels.map((l) => '#$l').join(' '));
  }
  return b.toString().trimRight();
}

/// Open the OS share sheet with one note's text.
Future<void> shareNoteText(Note n) => shareText(
      noteToPlainText(n),
      subject: n.title.trim().isEmpty ? 'KukKeep note' : n.title.trim(),
    );

/// Open the OS share sheet with arbitrary composed text.
Future<void> shareText(String text, {String? subject}) async {
  await SharePlus.instance.share(ShareParams(
    // Android's share intent rejects an empty EXTRA_TEXT; fall back to a space.
    text: text.isEmpty ? ' ' : text,
    subject: subject,
  ));
}

/// Share the editor's current (live) content as text.
Future<void> shareEditorText({
  required String title,
  required String body,
  required String type,
  required List<ChecklistItem> items,
  required List<String> labels,
}) {
  final text = _composeText(title: title, body: body, type: type, items: items, labels: labels);
  return shareText(text, subject: title.trim().isEmpty ? 'KukKeep note' : title.trim());
}

/// Export a set of notes to a single Markdown file and open the share sheet so
/// the user can save it (Drive / Files) or send it anywhere. Returns the number
/// of notes written, or 0 if there was nothing to export.
Future<int> exportNotesToFile(
  List<Note> notes, {
  String fileName = 'kukkeep-notes.md',
}) async {
  if (notes.isEmpty) return 0;
  final b = StringBuffer()
    ..writeln('# KukKeep export')
    ..writeln()
    ..writeln('${notes.length} note${notes.length == 1 ? '' : 's'}')
    ..writeln();
  for (final n in notes) {
    b.writeln('---');
    b.writeln();
    final title = n.title.trim().isEmpty ? '(untitled)' : n.title.trim();
    b.writeln('## $title');
    if (n.reminderAt != null && n.reminderAt!.isNotEmpty) {
      final rep = n.repeat != 'none' ? ' (${n.repeat})' : '';
      b.writeln('_Reminder: ${n.reminderAt}${rep}_');
    }
    b.writeln();
    if (n.type == 'checklist') {
      for (final it in n.items) {
        if (it.text.trim().isEmpty) continue;
        b.writeln('- [${it.done ? 'x' : ' '}] ${it.text.trim()}');
      }
    } else if (n.body.trim().isNotEmpty) {
      b.writeln(n.body.trim());
    }
    if (n.labels.isNotEmpty) {
      b.writeln();
      b.writeln(n.labels.map((l) => '#$l').join(' '));
    }
    b.writeln();
  }
  final data = Uint8List.fromList(utf8.encode(b.toString()));
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(data, mimeType: 'text/markdown')],
    // XFile.fromData ignores its `name`, so force the file name here.
    fileNameOverrides: [fileName],
    subject: 'KukKeep notes export',
  ));
  return notes.length;
}
