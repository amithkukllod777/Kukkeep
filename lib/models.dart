import 'dart:convert';

class Company {
  final int id;
  final String name;
  Company({required this.id, required this.name});
  factory Company.fromJson(Map<String, dynamic> j) =>
      Company(id: (j['id'] as num).toInt(), name: (j['name'] ?? 'Company').toString());
}

class ChecklistItem {
  String text;
  bool done;
  ChecklistItem({required this.text, this.done = false});
  factory ChecklistItem.fromJson(Map j) =>
      ChecklistItem(text: (j['text'] ?? '').toString(), done: j['done'] == true || j['done'] == 1);
  Map<String, dynamic> toJson() => {'text': text, 'done': done};
}

bool _asBool(dynamic v) => v == true || v == 1 || v == '1';

List<ChecklistItem> _parseItems(dynamic raw) {
  if (raw == null) return [];
  try {
    final a = raw is String ? jsonDecode(raw) : raw;
    if (a is List) return a.map((e) => ChecklistItem.fromJson(e as Map)).toList();
  } catch (_) {}
  return [];
}

List<String> _parseLabels(dynamic raw) {
  if (raw == null) return [];
  try {
    final a = raw is String ? jsonDecode(raw) : raw;
    if (a is List) return a.map((e) => e.toString()).toList();
  } catch (_) {}
  return [];
}

class Note {
  final int id;
  String title;
  String body;
  String type; // note | checklist
  List<ChecklistItem> items;
  String color;
  bool pinned;
  bool archived;
  List<String> labels;
  String? reminderAt;
  String repeat; // none | daily | weekly | monthly (reminder recurrence)
  String? coverImage; // first image attachment URL, for card thumbnails
  int attachmentCount; // total attachments on the note (for the 📎 indicator)

  Note({
    required this.id,
    this.title = '',
    this.body = '',
    this.type = 'note',
    this.items = const [],
    this.color = 'default',
    this.pinned = false,
    this.archived = false,
    this.labels = const [],
    this.reminderAt,
    this.repeat = 'none',
    this.coverImage,
    this.attachmentCount = 0,
  });

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: (j['id'] as num).toInt(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        type: (j['type'] ?? 'note').toString(),
        items: _parseItems(j['items']),
        color: (j['color'] ?? 'default').toString(),
        pinned: _asBool(j['pinned']),
        archived: _asBool(j['archived']),
        labels: _parseLabels(j['labels']),
        reminderAt: j['reminderAt']?.toString(),
        // Server returns `reminderRepeat` (drizzle prop); keep.list also aliases
        // it to `repeat`. Accept either, default none.
        repeat: (j['repeat'] ?? j['reminderRepeat'] ?? 'none').toString(),
        coverImage: (j['coverImage'] == null || j['coverImage'].toString().isEmpty) ? null : j['coverImage'].toString(),
        attachmentCount: (j['attachmentCount'] as num?)?.toInt() ?? 0,
      );

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty && items.where((i) => i.text.trim().isNotEmpty).isEmpty;
}

class Attachment {
  final int id;
  final int noteId;
  final String fileName;
  final String fileType;
  final String fileUrl;
  final int fileSize;
  final String? ocrText;
  Attachment({
    required this.id,
    required this.noteId,
    this.fileName = '',
    this.fileType = '',
    this.fileUrl = '',
    this.fileSize = 0,
    this.ocrText,
  });
  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: (j['id'] as num).toInt(),
        noteId: (j['noteId'] as num?)?.toInt() ?? 0,
        fileName: (j['fileName'] ?? '').toString(),
        fileType: (j['fileType'] ?? '').toString(),
        fileUrl: (j['fileUrl'] ?? '').toString(),
        fileSize: (j['fileSize'] as num?)?.toInt() ?? 0,
        ocrText: j['ocrText']?.toString(),
      );
  bool get isImage => fileType.startsWith('image/');
  bool get isAudio => fileType.startsWith('audio/'); // voice notes
}
