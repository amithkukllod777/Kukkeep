import 'package:flutter_test/flutter_test.dart';
import 'package:kukkeep/models.dart';
import 'package:kukkeep/share_export.dart';

// Covers the pure text/Markdown composition behind "Share note" and "Export
// notes" (the OS share-sheet call itself needs a plugin and isn't unit-tested).
// Run with `flutter test`.
void main() {
  group('noteToPlainText', () {
    test('text note = title then body', () {
      final n = Note.fromJson({'id': 1, 'title': 'Shopping', 'body': 'Buy milk'});
      expect(noteToPlainText(n), 'Shopping\nBuy milk');
    });

    test('checklist renders [x]/[ ] lines and skips blank items', () {
      final n = Note.fromJson({
        'id': 2, 'title': 'List', 'type': 'checklist',
        'items': [
          {'text': 'A', 'done': true},
          {'text': 'B', 'done': false},
          {'text': '   ', 'done': false},
        ],
      });
      expect(noteToPlainText(n), 'List\n[x] A\n[ ] B');
    });

    test('labels are appended as #tags after a blank line', () {
      final n = Note.fromJson({'id': 3, 'title': 'T', 'body': 'B', 'labels': ['home', 'work']});
      expect(noteToPlainText(n), 'T\nB\n\n#home #work');
    });

    test('an empty note produces empty text', () {
      expect(noteToPlainText(Note.fromJson({'id': 4})), '');
    });
  });

  group('notesToMarkdown', () {
    test('header carries the note count and each note becomes a section', () {
      final md = notesToMarkdown([Note.fromJson({'id': 1, 'title': 'A', 'body': 'x'})]);
      expect(md, contains('# KukKeep export'));
      expect(md, contains('1 note'));
      expect(md, contains('## A'));
      expect(md, contains('x'));
    });

    test('the count is pluralized for more than one note', () {
      final md = notesToMarkdown([
        Note.fromJson({'id': 1, 'title': 'A'}),
        Note.fromJson({'id': 2, 'title': 'B'}),
      ]);
      expect(md, contains('2 notes'));
    });

    test('checklist items become a Markdown task list', () {
      final md = notesToMarkdown([
        Note.fromJson({
          'id': 1, 'title': 'L', 'type': 'checklist',
          'items': [
            {'text': 'done', 'done': true},
            {'text': 'todo', 'done': false},
          ],
        }),
      ]);
      expect(md, contains('- [x] done'));
      expect(md, contains('- [ ] todo'));
    });

    test('an untitled note gets a placeholder heading', () {
      final md = notesToMarkdown([Note.fromJson({'id': 1, 'body': 'orphan'})]);
      expect(md, contains('## (untitled)'));
    });
  });
}
