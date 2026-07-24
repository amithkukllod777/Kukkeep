import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

typedef NoteBucket = ({bool archived, bool trashed});

/// Local-first cache for the notes list, plus a queue of writes made while
/// offline. `Api` reads/writes through this so KukKeep stays usable — viewing
/// AND editing notes — without connectivity, and catches up automatically the
/// next time a request actually reaches the server (see `Api.flushOutbox`).
///
/// Deliberately NOT a full local database: this is a personal single-user
/// notes app with a small dataset, so a per-view JSON blob in
/// SharedPreferences is simpler and safer to get right than adding a native
/// SQLite plugin with no device/emulator available to test it on.
class OfflineStore {
  OfflineStore._();
  static final OfflineStore instance = OfflineStore._();

  static const _kLive = 'kk_cache_live';
  static const _kArchived = 'kk_cache_archived';
  static const _kTrash = 'kk_cache_trash';
  static const _kOutbox = 'kk_outbox';
  static const _kNextTempId = 'kk_next_temp_id';

  static const NoteBucket live = (archived: false, trashed: false);
  static const NoteBucket archived = (archived: true, trashed: false);
  static const NoteBucket trash = (archived: false, trashed: true);
  static const List<NoteBucket> _allBuckets = [live, archived, trash];

  String _keyFor(NoteBucket b) => b.trashed ? _kTrash : (b.archived ? _kArchived : _kLive);

  Future<bool> hasCacheFor({required bool archived, required bool trashed}) async {
    final p = await SharedPreferences.getInstance();
    return p.containsKey(_keyFor((archived: archived, trashed: trashed)));
  }

  Future<void> saveNotes({required bool archived, required bool trashed, required List<Note> notes}) =>
      _saveBucket((archived: archived, trashed: trashed), notes);

  Future<List<Note>> loadNotes({required bool archived, required bool trashed}) =>
      _loadBucket((archived: archived, trashed: trashed));

  Future<List<Note>> _loadBucket(NoteBucket b) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_keyFor(b));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Note.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveBucket(NoteBucket b, List<Note> notes) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyFor(b), jsonEncode(notes.map(_encode).toList()));
  }

  Map<String, dynamic> _encode(Note n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'type': n.type,
        'items': n.items.map((e) => e.toJson()).toList(),
        'color': n.color,
        'pinned': n.pinned,
        'archived': n.archived,
        'labels': n.labels,
        'reminderAt': n.reminderAt,
        'repeat': n.repeat,
        'coverImage': n.coverImage,
        'attachmentCount': n.attachmentCount,
      };

  // ── Outbox: queued writes made while offline, replayed by Api.flushOutbox
  // once a request actually reaches the server again. ──

  Future<List<Map<String, dynamic>>> outbox() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kOutbox);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveOutbox(List<Map<String, dynamic>> ops) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOutbox, jsonEncode(ops));
  }

  Future<bool> hasPending() async => (await outbox()).isNotEmpty;

  /// Queue an op. When [coalesceLocalNoteId] matches an already-queued
  /// 'create' op, merges into its payload instead of adding a new entry —
  /// repeated offline edits to a note that hasn't synced yet must never stack
  /// up as separate ops against a server id that doesn't exist yet.
  Future<void> enqueue(String opType, Map<String, dynamic> payload, {int? coalesceLocalNoteId}) async {
    final ops = await outbox();
    if (coalesceLocalNoteId != null) {
      final idx = ops.indexWhere((o) => o['type'] == 'create' && o['localId'] == coalesceLocalNoteId);
      if (idx != -1) {
        final merged = <String, dynamic>{...Map<String, dynamic>.from(ops[idx]['payload']), ...payload};
        ops[idx] = {...ops[idx], 'payload': merged};
        await _saveOutbox(ops);
        return;
      }
    }
    ops.add({
      'opId': DateTime.now().microsecondsSinceEpoch,
      'type': opType,
      'payload': payload,
      if (coalesceLocalNoteId != null) 'localId': coalesceLocalNoteId,
    });
    await _saveOutbox(ops);
  }

  Future<void> removeOp(int opId) async {
    final ops = await outbox();
    ops.removeWhere((o) => o['opId'] == opId);
    await _saveOutbox(ops);
  }

  /// Temporary negative ids for notes created while offline — never collide
  /// with a real (always positive) server id.
  Future<int> nextTempId() async {
    final p = await SharedPreferences.getInstance();
    final next = (p.getInt(_kNextTempId) ?? 0) - 1;
    await p.setInt(_kNextTempId, next);
    return next;
  }

  // ── Cache mutation helpers — mirror each optimistic write into the cache
  // so a cold start while still offline shows the same state already on
  // screen, not stale pre-edit data. ──

  Future<void> cacheCreate(int id, Map<String, dynamic> input) async {
    final note = Note(
      id: id,
      title: (input['title'] ?? '').toString(),
      body: (input['body'] ?? '').toString(),
      type: (input['type'] ?? 'note').toString(),
      items: _itemsFrom(input['items']),
      color: (input['color'] ?? 'default').toString(),
      pinned: input['pinned'] == true,
      archived: input['archived'] == true,
      labels: List<String>.from(input['labels'] ?? const []),
      reminderAt: input['reminderAt']?.toString(),
      repeat: (input['repeat'] ?? 'none').toString(),
    );
    final b = note.archived ? archived : live;
    final list = await _loadBucket(b);
    list.insert(0, note); // newest first, like the server's list order
    await _saveBucket(b, list);
  }

  Future<void> cacheUpdate(int id, Map<String, dynamic> patch) async {
    for (final b in _allBuckets) {
      final list = await _loadBucket(b);
      final idx = list.indexWhere((n) => n.id == id);
      if (idx == -1) continue;
      final merged = _applyPatch(list[idx], patch);
      // A plain update can flip `archived` — move buckets when it does.
      // Trashed notes stay put; archived/pinned/etc. don't apply there.
      final target = b.trashed ? b : (merged.archived ? archived : live);
      if (target == b) {
        list[idx] = merged;
        await _saveBucket(b, list);
      } else {
        list.removeAt(idx);
        await _saveBucket(b, list);
        final destList = await _loadBucket(target);
        destList.insert(0, merged);
        await _saveBucket(target, destList);
      }
      return;
    }
  }

  Note _applyPatch(Note n, Map<String, dynamic> p) => Note(
        id: n.id,
        title: p.containsKey('title') ? (p['title'] ?? '').toString() : n.title,
        body: p.containsKey('body') ? (p['body'] ?? '').toString() : n.body,
        type: p.containsKey('type') ? (p['type'] ?? n.type).toString() : n.type,
        items: p.containsKey('items') ? _itemsFrom(p['items']) : n.items,
        color: p.containsKey('color') ? (p['color'] ?? n.color).toString() : n.color,
        pinned: p.containsKey('pinned') ? p['pinned'] == true : n.pinned,
        archived: p.containsKey('archived') ? p['archived'] == true : n.archived,
        labels: p.containsKey('labels') ? List<String>.from(p['labels'] ?? const []) : n.labels,
        reminderAt: p.containsKey('reminderAt') ? p['reminderAt']?.toString() : n.reminderAt,
        repeat: p.containsKey('repeat') ? (p['repeat'] ?? 'none').toString() : n.repeat,
        coverImage: n.coverImage,
        attachmentCount: n.attachmentCount,
      );

  List<ChecklistItem> _itemsFrom(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => ChecklistItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> cacheMoveToTrash(int id) async {
    for (final b in [live, archived]) {
      final list = await _loadBucket(b);
      final idx = list.indexWhere((n) => n.id == id);
      if (idx == -1) continue;
      final note = list.removeAt(idx);
      await _saveBucket(b, list);
      final t = await _loadBucket(trash);
      t.insert(0, note);
      await _saveBucket(trash, t);
      return;
    }
  }

  Future<void> cacheRestoreFromTrash(int id) async {
    final t = await _loadBucket(trash);
    final idx = t.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final note = t.removeAt(idx);
    await _saveBucket(trash, t);
    final l = await _loadBucket(live);
    l.insert(0, note);
    await _saveBucket(live, l);
  }

  Future<void> cacheRemove(int id) async {
    final t = await _loadBucket(trash);
    t.removeWhere((n) => n.id == id);
    await _saveBucket(trash, t);
  }

  Future<void> cacheEmptyTrash() => _saveBucket(trash, []);

  Future<void> cacheRenameLabel(String from, String to) async {
    for (final b in _allBuckets) {
      final list = await _loadBucket(b);
      var changed = false;
      for (final n in list) {
        if (n.labels.contains(from)) {
          n.labels = [for (final l in n.labels) l == from ? to : l];
          changed = true;
        }
      }
      if (changed) await _saveBucket(b, list);
    }
  }

  Future<void> cacheDeleteLabel(String label) async {
    for (final b in _allBuckets) {
      final list = await _loadBucket(b);
      var changed = false;
      for (final n in list) {
        if (n.labels.contains(label)) {
          n.labels = n.labels.where((l) => l != label).toList();
          changed = true;
        }
      }
      if (changed) await _saveBucket(b, list);
    }
  }

  /// A temp (never-synced) note was trashed/deleted before it ever reached
  /// the server — there's nothing to sync, so drop it from the cache and
  /// cancel its pending 'create' op entirely rather than queuing more work.
  Future<void> discardTempNote(int tempId) async {
    for (final b in [live, archived]) {
      final list = await _loadBucket(b);
      final before = list.length;
      list.removeWhere((n) => n.id == tempId);
      if (list.length != before) await _saveBucket(b, list);
    }
    final ops = await outbox();
    ops.removeWhere((o) => o['type'] == 'create' && o['localId'] == tempId);
    await _saveOutbox(ops);
  }

  /// A queued 'create' op finally reached the server — swap the temp id for
  /// the real one so the cache matches what the server now has.
  Future<void> replaceTempNoteId(int tempId, int realId) async {
    for (final b in [live, archived]) {
      final list = await _loadBucket(b);
      final idx = list.indexWhere((n) => n.id == tempId);
      if (idx == -1) continue;
      final old = list[idx];
      list[idx] = Note(
        id: realId,
        title: old.title,
        body: old.body,
        type: old.type,
        items: old.items,
        color: old.color,
        pinned: old.pinned,
        archived: old.archived,
        labels: old.labels,
        reminderAt: old.reminderAt,
        coverImage: old.coverImage,
        attachmentCount: old.attachmentCount,
      );
      await _saveBucket(b, list);
      return;
    }
  }
}
