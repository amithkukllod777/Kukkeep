import 'package:flutter_test/flutter_test.dart';
import 'package:kukkeep/models.dart';

// NOTE (qa-audit): written during the QA audit to cover the defensive JSON
// parsing in models.dart (the server payload shape is only loosely typed on
// the wire, so these fallbacks matter). Not executed here — no Flutter SDK in
// this environment. Run with `flutter test`; see qa-audit/TEST_COVERAGE_MATRIX.md.
void main() {
  group('Note.fromJson', () {
    test('parses a well-formed checklist note', () {
      final n = Note.fromJson({
        'id': 1,
        'title': 'Groceries',
        'type': 'checklist',
        'items': [
          {'text': 'Milk', 'done': false},
          {'text': 'Eggs', 'done': true},
        ],
        'color': 'blue',
        'pinned': true,
        'labels': ['home'],
      });
      expect(n.id, 1);
      expect(n.type, 'checklist');
      expect(n.items.length, 2);
      expect(n.items[1].done, true);
      expect(n.pinned, true);
      expect(n.labels, ['home']);
    });

    test('items as a JSON-encoded string (server may send it either shape)', () {
      final n = Note.fromJson({
        'id': 2,
        'items': '[{"text":"A","done":1}]', // done as 1, not true
        'type': 'checklist',
      });
      expect(n.items.length, 1);
      expect(n.items.first.done, true); // _asBool treats 1 as true
    });

    test('malformed items JSON falls back to an empty list instead of throwing', () {
      final n = Note.fromJson({'id': 3, 'items': 'not json', 'type': 'checklist'});
      expect(n.items, isEmpty);
    });

    test('null/missing optional fields fall back to safe defaults', () {
      final n = Note.fromJson({'id': 4});
      expect(n.title, '');
      expect(n.body, '');
      expect(n.type, 'note');
      expect(n.color, 'default');
      expect(n.pinned, false);
      expect(n.archived, false);
      expect(n.labels, isEmpty);
      expect(n.reminderAt, isNull);
      expect(n.coverImage, isNull);
      expect(n.attachmentCount, 0);
    });

    test('empty-string coverImage is treated as absent, not a broken URL', () {
      final n = Note.fromJson({'id': 5, 'coverImage': ''});
      expect(n.coverImage, isNull);
    });

    test('isEmpty is true only when title, body and all item text are blank', () {
      final blank = Note.fromJson({'id': 6, 'title': '  ', 'body': ''});
      expect(blank.isEmpty, true);
      final withTitle = Note.fromJson({'id': 7, 'title': 'x'});
      expect(withTitle.isEmpty, false);
    });
  });

  group('Attachment.fromJson', () {
    test('isImage checks the fileType prefix', () {
      final a = Attachment.fromJson({'id': 1, 'fileType': 'image/png'});
      expect(a.isImage, true);
      final b = Attachment.fromJson({'id': 2, 'fileType': 'application/pdf'});
      expect(b.isImage, false);
    });

    test('missing numeric fields default to 0, not null/throw', () {
      final a = Attachment.fromJson({'id': 3});
      expect(a.noteId, 0);
      expect(a.fileSize, 0);
    });
  });

  group('Company.fromJson', () {
    test('missing name falls back to a default label', () {
      final c = Company.fromJson({'id': 9});
      expect(c.name, 'Company');
    });
  });
}
