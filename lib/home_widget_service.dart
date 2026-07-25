import 'package:home_widget/home_widget.dart';
import 'models.dart';

/// Home-screen widget bridge (Google-Keep parity). Pushes a small summary of
/// the user's notes to the Android app-widget and asks it to redraw. The native
/// side (NotesWidgetProvider) reads these keys; tapping the widget opens the app.
///
/// Fully-qualified provider name is required because the app's applicationId
/// (com.kuklabs.keep) differs from the Kotlin package the provider lives in
/// (com.kuklabs.kukkeep, where MainActivity + the R class also live).
const String _kProvider = 'com.kuklabs.kukkeep.NotesWidgetProvider';

/// One-line label for a note (title, else joined body/checklist, else fallback).
String _labelFor(Note n) {
  final t = n.title.trim();
  if (t.isNotEmpty) return t;
  final body = n.type == 'checklist'
      ? n.items.where((i) => i.text.trim().isNotEmpty).map((i) => i.text.trim()).join(', ')
      : n.body.trim();
  return body.isNotEmpty ? body : 'Untitled note';
}

/// Update the home-screen widget from the current note list — shows up to 3
/// recent notes. Best-effort; never throws (plugin/widget may be absent).
Future<void> updateHomeWidget(List<Note> notes) async {
  try {
    // Pinned first, then the rest in existing (recency) order — mirrors the app.
    final live = notes.where((n) => !n.archived).toList();
    live.sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
    String slot(int i) => i < live.length ? _labelFor(live[i]) : '';
    await HomeWidget.saveWidgetData<String>('note_1', slot(0));
    await HomeWidget.saveWidgetData<String>('note_2', slot(1));
    await HomeWidget.saveWidgetData<String>('note_3', slot(2));
    await HomeWidget.saveWidgetData<int>('note_count', live.length);
    await HomeWidget.updateWidget(qualifiedAndroidName: _kProvider);
  } catch (_) {/* plugin/widget unavailable — ignore */}
}
