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

/// Update the home-screen widget from the current note list. Best-effort —
/// never throws (the widget/plugin may be absent, e.g. in tests or on iOS).
Future<void> updateHomeWidget(List<Note> notes) async {
  try {
    final live = notes.where((n) => !n.archived).toList();
    String title;
    String subtitle;
    if (live.isEmpty) {
      title = 'Kuk Keep';
      subtitle = 'Tap to add your first note';
    } else {
      // Prefer a pinned note, else the most recent (list is already ordered).
      final top = live.firstWhere((n) => n.pinned, orElse: () => live.first);
      final t = top.title.trim();
      final body = top.type == 'checklist'
          ? top.items.where((i) => i.text.trim().isNotEmpty).map((i) => i.text.trim()).join(', ')
          : top.body.trim();
      title = t.isNotEmpty ? t : (body.isNotEmpty ? body : 'Untitled note');
      subtitle = '${live.length} note${live.length == 1 ? '' : 's'} · tap to open';
    }
    await HomeWidget.saveWidgetData<String>('note_title', title);
    await HomeWidget.saveWidgetData<String>('note_subtitle', subtitle);
    await HomeWidget.updateWidget(qualifiedAndroidName: _kProvider);
  } catch (_) {/* plugin/widget unavailable — ignore */}
}
