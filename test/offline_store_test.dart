import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kukkeep/models.dart';
import 'package:kukkeep/offline_store.dart';

// Covers the offline-first note cache + outbox (qa-audit REMEDIATION_PLAN.md
// medium-term item). This is the correctness-critical piece of that feature —
// a bug here risks silently losing or duplicating a note — so it's exercised
// directly rather than through Api's network layer. Run with `flutter test`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Note note(int id, {String title = 'T', bool archived = false}) =>
      Note(id: id, title: title, archived: archived);

  group('read cache', () {
    test('hasCacheFor is false until a bucket is saved', () async {
      final store = OfflineStore.instance;
      expect(await store.hasCacheFor(archived: false, trashed: false), false);
      await store.saveNotes(archived: false, trashed: false, notes: [note(1)]);
      expect(await store.hasCacheFor(archived: false, trashed: false), true);
      // A different bucket is unaffected.
      expect(await store.hasCacheFor(archived: true, trashed: false), false);
    });

    test('saveNotes/loadNotes round-trips every field', () async {
      final store = OfflineStore.instance;
      final n = Note(
        id: 5, title: 'Groceries', body: 'Milk', type: 'checklist',
        items: [ChecklistItem(text: 'Milk', done: true)],
        color: 'blue', pinned: true, archived: false,
        labels: ['home', 'urgent'], reminderAt: '2026-01-01T00:00:00.000Z',
        coverImage: '/x.png', attachmentCount: 2,
      );
      await store.saveNotes(archived: false, trashed: false, notes: [n]);
      final loaded = await store.loadNotes(archived: false, trashed: false);
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 5);
      expect(loaded.first.title, 'Groceries');
      expect(loaded.first.items.single.done, true);
      expect(loaded.first.labels, ['home', 'urgent']);
      expect(loaded.first.pinned, true);
    });

    test('loadNotes returns empty for a bucket never saved', () async {
      expect(await OfflineStore.instance.loadNotes(archived: false, trashed: true), isEmpty);
    });
  });

  group('cacheUpdate', () {
    test('a plain field patch stays in the same bucket', () async {
      final store = OfflineStore.instance;
      await store.saveNotes(archived: false, trashed: false, notes: [note(1, title: 'Old')]);
      await store.cacheUpdate(1, {'title': 'New'});
      final live = await store.loadNotes(archived: false, trashed: false);
      expect(live.single.title, 'New');
    });

    test('an archived:true patch moves the note from live to archived', () async {
      final store = OfflineStore.instance;
      await store.saveNotes(archived: false, trashed: false, notes: [note(1)]);
      await store.saveNotes(archived: true, trashed: false, notes: []);
      await store.cacheUpdate(1, {'archived': true});
      expect(await store.loadNotes(archived: false, trashed: false), isEmpty);
      final archivedList = await store.loadNotes(archived: true, trashed: false);
      expect(archivedList, hasLength(1));
      expect(archivedList.single.id, 1);
      expect(archivedList.single.archived, true);
    });

    test('an archived:false patch moves the note back to live', () async {
      final store = OfflineStore.instance;
      await store.saveNotes(archived: true, trashed: false, notes: [note(2, archived: true)]);
      await store.saveNotes(archived: false, trashed: false, notes: []);
      await store.cacheUpdate(2, {'archived': false});
      expect(await store.loadNotes(archived: true, trashed: false), isEmpty);
      expect((await store.loadNotes(archived: false, trashed: false)).single.id, 2);
    });

    test('a partial patch preserves fields it does not mention', () async {
      final store = OfflineStore.instance;
      final n = Note(id: 3, title: 'Keep me', body: 'body', pinned: true, labels: ['x']);
      await store.saveNotes(archived: false, trashed: false, notes: [n]);
      await store.cacheUpdate(3, {'body': 'new body'});
      final updated = (await store.loadNotes(archived: false, trashed: false)).single;
      expect(updated.title, 'Keep me');
      expect(updated.pinned, true);
      expect(updated.labels, ['x']);
      expect(updated.body, 'new body');
    });
  });

  group('trash / restore / remove', () {
    test('cacheMoveToTrash moves a note out of live into trash', () async {
      final store = OfflineStore.instance;
      await store.saveNotes(archived: false, trashed: false, notes: [note(1)]);
      await store.saveNotes(archived: false, trashed: true, notes: []);
      await store.cacheMoveToTrash(1);
      expect(await store.loadNotes(archived: false, trashed: false), isEmpty);
      expect((await store.loadNotes(archived: false, trashed: true)).single.id, 1);
    });

    test('cacheMoveToTrash finds the note in archived too', () async {
      final store = OfflineStore.instance;
      await store.saveNotes(archived: true, trashed: false, notes: [note(1, archived: true)]);
      await store.saveNotes(archived: false, trashed: true, notes: []);
      await store.cacheMoveToTrash(1);
      expect(await store.loadNotes(archived: true, trashed: false), isEmpty);
      expect((await store.loadNotes(archived: false, trashed: true)).single.id, 1);
    });

    test('cacheRestoreFromTrash moves a note back to live', () async {
      final store = OfflineStore.instance;
      await store.saveNotes(archived: false, trashed: true, notes: [note(1)]);
      await store.saveNotes(archived: false, trashed: false, notes: []);
      await store.cacheRestoreFromTrash(1);
      expect(await store.loadNotes(archived: false, trashed: true), isEmpty);
      expect((await store.loadNotes(archived: false, trashed: false)).single.id, 1);
    });

    test('cacheRemove deletes a note from trash permanently', () async {
      final store = OfflineStore.instance;
      await store.saveNotes(archived: false, trashed: true, notes: [note(1), note(2)]);
      await store.cacheRemove(1);
      final t = await store.loadNotes(archived: false, trashed: true);
      expect(t.map((n) => n.id), [2]);
    });

    test('cacheEmptyTrash clears the trash bucket', () async {
      final store = OfflineStore.instance;
      await store.saveNotes(archived: false, trashed: true, notes: [note(1), note(2)]);
      await store.cacheEmptyTrash();
      expect(await store.loadNotes(archived: false, trashed: true), isEmpty);
    });
  });

  group('labels', () {
    test('cacheRenameLabel updates the label on every matching note across buckets', () async {
      final store = OfflineStore.instance;
      await store.saveNotes(archived: false, trashed: false, notes: [Note(id: 1, labels: ['work', 'x'])]);
      await store.saveNotes(archived: true, trashed: false, notes: [Note(id: 2, labels: ['work'], archived: true)]);
      await store.cacheRenameLabel('work', 'office');
      final live = await store.loadNotes(archived: false, trashed: false);
      final arch = await store.loadNotes(archived: true, trashed: false);
      expect(live.single.labels, ['office', 'x']);
      expect(arch.single.labels, ['office']);
    });

    test('cacheDeleteLabel removes the label but keeps the note', () async {
      final store = OfflineStore.instance;
      await store.saveNotes(archived: false, trashed: false, notes: [Note(id: 1, labels: ['a', 'b'])]);
      await store.cacheDeleteLabel('a');
      final live = await store.loadNotes(archived: false, trashed: false);
      expect(live.single.labels, ['b']);
    });
  });

  group('outbox + temp notes', () {
    test('nextTempId returns distinct decreasing negative ids', () async {
      final store = OfflineStore.instance;
      final a = await store.nextTempId();
      final b = await store.nextTempId();
      expect(a, lessThan(0));
      expect(b, lessThan(a));
    });

    test('enqueue with no coalesce id adds a new op', () async {
      final store = OfflineStore.instance;
      await store.enqueue('update', {'id': 1, 'title': 'x'});
      final ops = await store.outbox();
      expect(ops, hasLength(1));
      expect(ops.single['type'], 'update');
    });

    test('enqueue coalesces repeated edits into the same pending create', () async {
      final store = OfflineStore.instance;
      await store.enqueue('create', {'title': 'first'}, coalesceLocalNoteId: -1);
      await store.enqueue('create', {'body': 'added later'}, coalesceLocalNoteId: -1);
      final ops = await store.outbox();
      expect(ops, hasLength(1)); // still one op, not two
      final payload = Map<String, dynamic>.from(ops.single['payload']);
      expect(payload['title'], 'first'); // earlier field preserved
      expect(payload['body'], 'added later'); // merged in
    });

    test('removeOp drops only the matching op', () async {
      final store = OfflineStore.instance;
      await store.enqueue('update', {'id': 1});
      await store.enqueue('update', {'id': 2});
      final ops = await store.outbox();
      await store.removeOp(ops.first['opId'] as int);
      final remaining = await store.outbox();
      expect(remaining, hasLength(1));
      expect(Map<String, dynamic>.from(remaining.single['payload'])['id'], 2);
    });

    test('discardTempNote removes the cached note and cancels its pending create', () async {
      final store = OfflineStore.instance;
      await store.cacheCreate(-1, {'title': 'temp'});
      await store.enqueue('create', {'title': 'temp'}, coalesceLocalNoteId: -1);
      await store.discardTempNote(-1);
      expect(await store.loadNotes(archived: false, trashed: false), isEmpty);
      expect(await store.outbox(), isEmpty);
    });

    test('replaceTempNoteId swaps the id but keeps every other field', () async {
      final store = OfflineStore.instance;
      await store.cacheCreate(-1, {'title': 'Offline note', 'pinned': true});
      await store.replaceTempNoteId(-1, 42);
      final live = await store.loadNotes(archived: false, trashed: false);
      expect(live.single.id, 42);
      expect(live.single.title, 'Offline note');
      expect(live.single.pinned, true);
    });
  });
}
