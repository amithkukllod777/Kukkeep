import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../auth_messages.dart';
import '../l10n/strings.dart';
import '../models.dart';
import '../note_colors.dart';
import '../note_templates.dart';
import '../notifications.dart';
import 'auth_screen.dart';
import 'note_editor_screen.dart';
import 'settings_screen.dart';
import 'ai_memory_screen.dart';

// Google Keep–style card height caps: list cards preview only this much; the
// full note shows when opened.
const int _kCardItemCap = 12;   // max checklist items shown on a card
const int _kCardBodyLines = 14; // max body lines shown on a card

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  // view: notes | reminders | archive | trash | label
  String _view = 'notes';
  String? _activeLabel;
  List<Note> _notes = [];      // notes for the current view
  List<Note> _liveNotes = [];     // non-archived, non-trashed (search corpus part 1)
  List<Note> _archivedNotes = []; // archived, non-trashed (search corpus part 2)
  List<String> _labels = [];   // labels across live notes (for the drawer)
  bool _grid = true;
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();
  String? _error;
  bool _offline = false; // last _load() served the local cache (Api.isOffline)

  // Multi-select (bulk actions) — long-press a card to enter.
  final Set<int> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  bool get _isTrash => _view == 'trash';
  bool get _isArchive => _view == 'archive';

  @override
  void initState() {
    super.initState();
    _restoreLayoutPref();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Remember the grid/list choice across launches (like Google Keep).
  Future<void> _restoreLayoutPref() async {
    final p = await SharedPreferences.getInstance();
    if (mounted && p.containsKey('kk_grid')) setState(() => _grid = p.getBool('kk_grid') ?? true);
  }

  Future<void> _setGrid(bool grid) async {
    setState(() => _grid = grid);
    final p = await SharedPreferences.getInstance();
    await p.setBool('kk_grid', grid);
  }

  Future<void> _load() async {
    // Keep the list visible during pull-to-refresh; only show the full-screen
    // spinner when there's nothing on screen yet.
    setState(() { if (_notes.isEmpty) _loading = true; _error = null; });
    try {
      final live = await Api.instance.notes(); // archived:false, trashed:false
      // Always fetch archived too (not just when Archive is the open view) so
      // search can span the whole live+archived corpus regardless of which
      // view is open (BUG-003 — search used to be silently scoped to
      // whichever view was on screen).
      final archived = await Api.instance.notes(archived: true);
      List<Note> display;
      if (_isArchive) {
        display = archived;
      } else if (_isTrash) {
        display = await Api.instance.notes(trashed: true);
      } else {
        display = live;
      }
      final labelSet = <String>{};
      for (final n in live) { labelSet.addAll(n.labels); }
      if (!mounted) return;
      setState(() {
        _notes = display;
        _liveNotes = live;
        _archivedNotes = archived;
        _labels = labelSet.toList()..sort();
        // Reflects the last of the notes() calls above — all made back-to-back
        // under the same connectivity, so this is representative of the batch.
        _offline = Api.instance.isOffline;
      });
      _rescheduleReminders(live); // keep OS reminders in sync with the notes
    } on ApiError catch (e) {
      if (e.unauthorized) { _logout(); return; }
      if (mounted) setState(() => _error = friendlyError(e));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Re-arm OS notifications for any live notes that have a future reminder, so
  // reminders keep working after the app (or device) was restarted.
  void _rescheduleReminders(List<Note> live) {
    for (final n in live) {
      if (n.reminderAt == null) continue;
      DateTime? when;
      try { when = DateTime.parse(n.reminderAt!).toLocal(); } catch (_) { continue; }
      // Re-arm future one-shots, and ALL recurring reminders (a recurring one
      // rolls to its next occurrence even when its base time is in the past).
      if (when.isAfter(DateTime.now()) || n.repeat != 'none') {
        final body = n.type == 'note' ? n.body : n.items.where((i) => i.text.trim().isNotEmpty).map((i) => i.text.trim()).join(', ');
        Notifications.instance.schedule(noteId: n.id, title: n.title, body: body, when: when, repeat: n.repeat);
      }
    }
  }

  Future<void> _logout() async {
    await Notifications.instance.cancelAll(); // don't fire the old account's reminders
    await Api.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  void _setView(String v, {String? label}) {
    _searchCtrl.clear();
    setState(() { _view = v; _activeLabel = label; _search = ''; _selected.clear(); });
    Navigator.of(context).pop(); // close drawer
    _load();
  }

  List<Note> get _filtered {
    final q = _search.trim().toLowerCase();
    // A non-empty search spans the whole live+archived corpus regardless of
    // which view is open (BUG-003) — Trash stays separately scoped, matching
    // the convention that deleted items don't surface in general search.
    var list = (q.isNotEmpty && !_isTrash) ? [..._liveNotes, ..._archivedNotes] : _notes;
    if (_view == 'reminders') list = list.where((n) => n.reminderAt != null).toList();
    if (_view == 'label' && _activeLabel != null) list = list.where((n) => n.labels.contains(_activeLabel)).toList();
    if (q.isNotEmpty) {
      list = list.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.body.toLowerCase().contains(q) ||
        n.items.any((i) => i.text.toLowerCase().contains(q)) ||
        n.labels.any((l) => l.toLowerCase().contains(q))).toList();
    }
    return list;
  }

  Future<void> _openEditor([Note? note]) async {
    if (_isTrash) return; // trashed notes aren't editable
    if (_selecting && note != null) { _toggleSelect(note.id); return; }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
    if (changed == true) _load();
  }

  // New note via the "+" button: offer a starter template first, then open the
  // editor seeded with the choice (blank template = an empty note).
  Future<void> _newNote() async {
    final nav = Navigator.of(context);
    final t = await showTemplatePicker(context);
    if (t == null || !mounted) return;
    final changed = await nav.push<bool>(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(template: t)));
    if (changed == true) _load();
  }

  // ── Bulk actions (long-press a card to enter multi-select) ──
  void _toggleSelect(int id) {
    setState(() { if (!_selected.add(id)) _selected.remove(id); });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _bulkArchive() async {
    // In the Archive view every selected note is already archived, so this
    // action un-archives; everywhere else it archives — a plain toggle of
    // "the opposite of the current view".
    final archiving = !_isArchive;
    final ids = _selected.toList();
    setState(_selected.clear);
    try {
      for (final id in ids) {
        if (archiving) Notifications.instance.cancel(id); // archiving stops its reminder
        await Api.instance.updateNote({'id': id, 'archived': archiving});
      }
      _load();
    } catch (e) { _snack(friendlyError(e)); }
  }

  Future<void> _bulkTrash() async {
    final ids = _selected.toList();
    setState(_selected.clear);
    try {
      for (final id in ids) {
        Notifications.instance.cancel(id);
        await Api.instance.trashNote(id);
      }
      _load();
      if (mounted) _snack('${ids.length} note${ids.length == 1 ? '' : 's'} moved to Trash');
    } catch (e) { _snack(friendlyError(e)); }
  }

  Future<void> _toggleItem(Note n, int idx) async {
    setState(() => n.items[idx].done = !n.items[idx].done);
    try { await Api.instance.updateNote({'id': n.id, 'items': n.items.map((e) => e.toJson()).toList()}); }
    catch (_) { _load(); }
  }

  Future<void> _quick(Note n, Map<String, dynamic> patch) async {
    try {
      // Archived notes don't fire reminders (they're re-armed on unarchive via _load).
      if (patch['archived'] == true) Notifications.instance.cancel(n.id);
      await Api.instance.updateNote({'id': n.id, ...patch}); _load();
    }
    catch (e) { _snack(friendlyError(e)); }
  }

  Future<void> _trash(Note n) async {
    try {
      Notifications.instance.cancel(n.id); // a trashed note must not fire its reminder
      await Api.instance.trashNote(n.id); _load();
      if (!mounted) return;
      // One-tap Undo (like Google Keep) instead of a dead-end snackbar.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Moved to Trash'),
        action: SnackBarAction(label: 'Undo', onPressed: () async {
          try { await Api.instance.restoreNote(n.id); _load(); } catch (_) {}
        }),
      ));
    }
    catch (e) { _snack(friendlyError(e)); }
  }

  Future<void> _restore(Note n) async {
    try { await Api.instance.restoreNote(n.id); _load(); _snack('Restored'); }
    catch (e) { _snack(friendlyError(e)); }
  }

  Future<void> _deleteForever(Note n) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete forever?'),
      content: const Text('This note will be permanently deleted.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ]));
    if (ok == true) {
      try {
        Notifications.instance.cancel(n.id); // deleted note must not fire its reminder
        await Api.instance.removeNote(n.id); _load();
      } catch (e) { _snack(friendlyError(e)); }
    }
  }

  Future<void> _emptyTrash() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Empty Trash?'),
      content: const Text('All notes in Trash will be permanently deleted.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Empty', style: TextStyle(color: Colors.red))),
      ]));
    if (ok == true) {
      try {
        for (final n in _notes) { Notifications.instance.cancel(n.id); } // trash view → drop any stray alarms
        await Api.instance.emptyTrash(); _load();
      } catch (e) { _snack(friendlyError(e)); }
    }
  }

  Future<void> _renameLabel(String l) async {
    final ctrl = TextEditingController(text: l);
    final to = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: const Text('Rename label'),
      content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Rename')),
      ]));
    ctrl.dispose(); // dialog is closed; free the controller
    if (to != null && to.isNotEmpty && to != l) {
      try { await Api.instance.renameLabel(l, to); if (_activeLabel == l) _activeLabel = to; _load(); }
      catch (e) { _snack(friendlyError(e)); }
    }
  }

  Future<void> _deleteLabel(String l) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text('Delete label "$l"?'),
      content: const Text('It will be removed from all notes. The notes themselves are kept.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ]));
    if (ok == true) {
      try { await Api.instance.deleteLabel(l); if (_view == 'label' && _activeLabel == l) { _view = 'notes'; _activeLabel = null; } _load(); }
      catch (e) { _snack(friendlyError(e)); }
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String get _title {
    switch (_view) {
      case 'reminders': return 'Reminders';
      case 'archive': return 'Archive';
      case 'trash': return 'Trash';
      case 'label': return _activeLabel ?? 'Label';
      default: return 'Kuk Keep';
    }
  }

  // Bulk-action app bar shown while one or more cards are long-press-selected.
  AppBar _selectionAppBar() {
    return AppBar(
      backgroundColor: kBrand,
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: 'Cancel selection',
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      title: Text('${_selected.length} selected'),
      actions: [
        IconButton(
          tooltip: _isArchive ? 'Unarchive selected' : 'Archive selected',
          icon: Icon(_isArchive ? Icons.unarchive_outlined : Icons.archive_outlined),
          onPressed: _bulkArchive,
        ),
        IconButton(
          tooltip: 'Move selected to Trash',
          icon: const Icon(Icons.delete_outline),
          onPressed: _bulkTrash,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final pinned = _isTrash ? <Note>[] : list.where((n) => n.pinned).toList();
    final others = _isTrash ? list : list.where((n) => !n.pinned).toList();
    return Scaffold(
      drawer: _selecting ? null : _buildDrawer(),
      appBar: _selecting ? _selectionAppBar() : AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(children: [
          if (_view == 'notes') Image.asset(kLogoAsset, width: 26, height: 26) else const SizedBox.shrink(),
          if (_view == 'notes') const SizedBox(width: 8),
          Text(_title, style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.w700, fontFamily: kDisplayFont, fontSize: 22)),
        ]),
        actions: [
          IconButton(
            tooltip: _grid ? 'List view' : 'Grid view',
            icon: Icon(_grid ? Icons.view_agenda_outlined : Icons.grid_view, color: kBrand),
            onPressed: () => _setGrid(!_grid),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            // Floating pill search bar over the off-white canvas.
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [BoxShadow(color: kCardShadow, blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: tr('search_notes'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _search.isEmpty ? null : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); },
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: (_isTrash || _isArchive) ? null : FloatingActionButton.extended(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        onPressed: _newNote,
        icon: const Icon(Icons.add),
        label: Text(tr('notes')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kBrand))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_offline) _offlineBanner(),
                      if (_isTrash && _notes.isNotEmpty) _trashBanner(),
                      if (list.isEmpty)
                        Padding(padding: const EdgeInsets.only(top: 80), child: _emptyView()),
                      if (pinned.isNotEmpty) ...[_sectionLabel('PINNED'), _masonry(pinned)],
                      if (others.isNotEmpty) ...[
                        if (pinned.isNotEmpty) _sectionLabel('OTHERS'),
                        _masonry(others),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  // Shown when Api.notes() had to fall back to the local cache (offline-first
  // note cache: qa-audit REMEDIATION_PLAN.md). Edits made now still work —
  // they queue locally and sync automatically once a request gets through.
  Widget _offlineBanner() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.cloud_off_outlined, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text('Offline — showing your last synced notes. Changes will sync automatically.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
      ]),
    );
  }

  Widget _trashBanner() {
    final cs = Theme.of(context).colorScheme; // readable in both light & dark themes
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.delete_outline, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text('Notes in Trash are deleted after 30 days.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        TextButton(onPressed: _emptyTrash, child: const Text('Empty Trash', style: TextStyle(color: Colors.red, fontSize: 12))),
      ]),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Row(children: [
                Image.asset(kLogoAsset, width: 34, height: 34),
                const SizedBox(width: 10),
                const Text('Kuk Keep', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
            ),
            _drawerTile('notes', 'Notes', Icons.lightbulb_outline),
            _drawerTile('reminders', 'Reminders', Icons.notifications_none),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('AI Memory'),
              onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiMemoryScreen())); },
            ),
            if (_labels.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(20, 12, 16, 4),
                child: Text('LABELS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1))),
              for (final l in _labels)
                ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(l),
                  selected: _view == 'label' && _activeLabel == l,
                  selectedTileColor: kBrand.withOpacity(0.12),
                  onTap: () => _setView('label', label: l),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (v) {
                      if (v == 'rename') { _renameLabel(l); } else if (v == 'delete') { _deleteLabel(l); }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
            ],
            const Divider(),
            _drawerTile('archive', 'Archive', Icons.archive_outlined),
            _drawerTile('trash', 'Trash', Icons.delete_outline),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(String view, String label, IconData icon) => ListTile(
        leading: Icon(icon, color: _view == view ? kBrand : null),
        title: Text(label, style: TextStyle(fontWeight: _view == view ? FontWeight.bold : FontWeight.normal)),
        selected: _view == view,
        selectedTileColor: kBrand.withOpacity(0.12),
        onTap: () => _setView(view),
      );

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: Colors.grey)),
      );

  Widget _emptyView() {
    final msg = _search.isNotEmpty ? 'No matching notes.'
      : _isTrash ? 'Trash is empty.'
      : _isArchive ? 'No archived notes.'
      : _view == 'reminders' ? 'No notes with reminders yet.'
      : _view == 'label' ? 'No notes with this label.'
      : 'Tap + to add your first note.';
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(_isTrash ? Icons.delete_outline : Icons.lightbulb_outline, size: 56, color: Colors.grey.shade400),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(color: Colors.grey.shade600)),
    ]));
  }

  Widget _masonry(List<Note> notes) {
    if (!_grid) {
      return Column(children: notes.map(_card).toList());
    }
    final left = <Note>[]; final right = <Note>[];
    for (var i = 0; i < notes.length; i++) { (i.isEven ? left : right).add(notes[i]); }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(children: left.map(_card).toList())),
      const SizedBox(width: 10),
      Expanded(child: Column(children: right.map(_card).toList())),
    ]);
  }

  // Highlights search matches in card text with a soft yellow marker (like the
  // reference "smart search" design). Falls back to plain text when no query.
  Widget _hl(String text, TextStyle style, {int? maxLines}) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty || !text.toLowerCase().contains(q)) {
      return Text(text, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null, style: style);
    }
    final spans = <TextSpan>[];
    var rest = text;
    while (true) {
      final at = rest.toLowerCase().indexOf(q);
      if (at < 0) { spans.add(TextSpan(text: rest)); break; }
      if (at > 0) spans.add(TextSpan(text: rest.substring(0, at)));
      spans.add(TextSpan(
        text: rest.substring(at, at + q.length),
        style: const TextStyle(backgroundColor: kHighlight, color: Colors.black87, fontWeight: FontWeight.w600),
      ));
      rest = rest.substring(at + q.length);
      if (rest.isEmpty) break;
    }
    return Text.rich(TextSpan(style: style, children: spans),
        maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null);
  }

  Widget _card(Note n) {
    final selected = _selected.contains(n.id);
    return GestureDetector(
      onTap: () => _selecting ? _toggleSelect(n.id) : _openEditor(n),
      onLongPress: _isTrash ? null : () => _toggleSelect(n.id),
      child: Stack(children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: noteColor(n.color),
            border: selected
                ? Border.all(color: kBrand, width: 2)
                : (n.color == 'default' ? Border.all(color: Colors.black.withOpacity(0.05)) : null),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: kCardShadow, blurRadius: 12, offset: Offset(0, 4))],
          ),
          // Selection mode suppresses each control's own tap so the whole card
          // toggles selection instead of firing pin/checklist/archive/trash actions.
          child: IgnorePointer(
            ignoring: _selecting,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (n.coverImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: Api.instance.absoluteUrl(n.coverImage!),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      placeholder: (_, __) => Container(height: 120, alignment: Alignment.center, color: Colors.black12,
                          child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                  ),
                ),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (n.title.isNotEmpty)
                  Expanded(child: _hl(n.title, const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Colors.black87, height: 1.25, fontFamily: kDisplayFont)))
                else const Spacer(),
                if (!_isTrash)
                  Tooltip(
                    message: n.pinned ? 'Unpin' : 'Pin',
                    child: InkWell(onTap: () => _quick(n, {'pinned': !n.pinned}),
                      child: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18, color: n.pinned ? kBrand : Colors.black38)),
                  ),
              ]),
              if (n.title.isNotEmpty) const SizedBox(height: 6),
              if (n.type == 'checklist') ...[
                // Cap the card height like Google Keep: unchecked items first (up to
                // the cap); checked ones collapse into a "completed" summary line.
                ...(() {
                  final unchecked = n.items.asMap().entries.where((e) => !e.value.done).toList();
                  final doneCount = n.items.length - unchecked.length;
                  return <Widget>[
                    ...unchecked.take(_kCardItemCap).map((e) => Tooltip(
                          message: 'Mark done',
                          child: InkWell(
                            onTap: _isTrash ? null : () => _toggleItem(n, e.key),
                            child: Padding(padding: const EdgeInsets.symmetric(vertical: 3.5), child: Row(children: [
                              const Icon(Icons.check_box_outline_blank, size: 18, color: Colors.black45),
                              const SizedBox(width: 8),
                              Expanded(child: _hl(e.value.text, const TextStyle(fontSize: 14, height: 1.3, color: Colors.black87), maxLines: 2)),
                            ])),
                          ),
                        )),
                    if (unchecked.length > _kCardItemCap)
                      Padding(padding: const EdgeInsets.only(top: 4, left: 2),
                        child: Text('+ ${unchecked.length - _kCardItemCap} more items', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500))),
                    if (doneCount > 0)
                      Padding(padding: const EdgeInsets.only(top: 5, left: 2), child: Row(children: [
                        const Icon(Icons.check, size: 14, color: Colors.black38),
                        const SizedBox(width: 6),
                        Text('$doneCount completed item${doneCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                      ])),
                  ];
                })(),
              ]
              else if (n.body.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 2), child: _hl(n.body, const TextStyle(fontSize: 14, height: 1.35, color: Colors.black87), maxLines: _kCardBodyLines)),
              if (n.labels.isNotEmpty || n.reminderAt != null || n.attachmentCount > 0 || n.id < 0)
                Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 4, children: [
                  // Offline-created note, not yet synced (qa-audit REMEDIATION_PLAN.md) —
                  // syncs automatically once the app can reach the server again.
                  if (n.id < 0) _chip('Not synced', Icons.cloud_off, brand: true),
                  for (final l in n.labels) _chip(l, Icons.label_outline),
                  if (n.attachmentCount > 0) _chip('${n.attachmentCount}', Icons.attach_file),
                  if (n.reminderAt != null) _chip(_fmt(n.reminderAt!), Icons.notifications_none, brand: true),
                ])),
              Padding(padding: const EdgeInsets.only(top: 8), child: _isTrash
                ? Row(children: [
                    TextButton.icon(onPressed: () => _restore(n), icon: const Icon(Icons.restore, size: 16, color: Colors.green), label: const Text('Restore', style: TextStyle(color: Colors.green, fontSize: 12))),
                    const Spacer(),
                    TextButton.icon(onPressed: () => _deleteForever(n), icon: const Icon(Icons.delete_forever, size: 16, color: Colors.red), label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12))),
                  ])
                : Row(children: [
                    // Padded InkWells → comfortable ~40dp tap targets on card actions.
                    Tooltip(
                      message: n.archived ? 'Unarchive' : 'Archive',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _quick(n, {'archived': !n.archived}),
                        child: Padding(padding: const EdgeInsets.all(10), child: Icon(n.archived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 18, color: Colors.black38)),
                      ),
                    ),
                    Tooltip(
                      message: 'Delete',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _trash(n),
                        child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.delete_outline, size: 18, color: Colors.black38)),
                      ),
                    ),
                  ])),
            ]),
          ),
        ),
        if (selected)
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ),
      ]),
    );
  }

  Widget _chip(String text, IconData icon, {bool brand = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: brand ? kBrandDark : Colors.black54),
          const SizedBox(width: 3),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: brand ? kBrandDark : Colors.black54))),
        ]),
      );

  String _fmt(String iso) {
    try { return DateFormat('MMM d, h:mm a').format(DateTime.parse(iso).toLocal()); } catch (_) { return ''; }
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 16),
      FilledButton(onPressed: onRetry, style: FilledButton.styleFrom(backgroundColor: kBrand), child: const Text('Retry')),
    ])));
  }
}
