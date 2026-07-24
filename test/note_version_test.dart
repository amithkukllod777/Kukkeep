import 'package:flutter_test/flutter_test.dart';
import 'package:kukkeep/models.dart';

// Covers NoteVersion parsing + the one-line preview shown in the version-history
// sheet. Same defensive-JSON contract as Note.fromJson. Run with `flutter test`.
void main() {
  group('NoteVersion.fromJson', () {
    test('parses content fields', () {
      final v = NoteVersion.fromJson({'id': 5, 'title': 'T', 'body': 'B', 'type': 'note'});
      expect(v.id, 5);
      expect(v.title, 'T');
      expect(v.body, 'B');
      expect(v.type, 'note');
    });

    test('parses checklist items as an array or a JSON string', () {
      final v = NoteVersion.fromJson({
        'id': 1, 'type': 'checklist',
        'items': [{'text': 'x', 'done': true}],
      });
      expect(v.items.length, 1);
      expect(v.items.first.done, true);

      final v2 = NoteVersion.fromJson({
        'id': 2, 'type': 'checklist',
        'items': '[{"text":"y","done":0}]',
      });
      expect(v2.items.first.text, 'y');
      expect(v2.items.first.done, false); // 0 → false
    });

    test('createdAt parses an ISO timestamp, null when absent', () {
      final v = NoteVersion.fromJson({'id': 1, 'createdAt': '2026-01-02T03:04:05.000Z'});
      expect(v.createdAt, isNotNull);
      expect(NoteVersion.fromJson({'id': 2}).createdAt, isNull);
    });

    test('missing fields fall back to safe defaults', () {
      final v = NoteVersion.fromJson({'id': 9});
      expect(v.title, '');
      expect(v.body, '');
      expect(v.type, 'note');
      expect(v.items, isEmpty);
    });
  });

  group('NoteVersion.preview', () {
    test('text preview prefers the body and flattens newlines', () {
      final v = NoteVersion.fromJson({'id': 1, 'title': 'T', 'body': 'line1\nline2'});
      expect(v.preview, 'line1 line2');
    });

    test('text preview falls back to the title when the body is empty', () {
      final v = NoteVersion.fromJson({'id': 1, 'title': 'Only title'});
      expect(v.preview, 'Only title');
    });

    test('checklist preview shows the done/total count', () {
      final v = NoteVersion.fromJson({
        'id': 1, 'type': 'checklist',
        'items': [
          {'text': 'a', 'done': true},
          {'text': 'b', 'done': false},
        ],
      });
      expect(v.preview, startsWith('✓ 1/2'));
      expect(v.preview, contains('a'));
    });
  });
}
