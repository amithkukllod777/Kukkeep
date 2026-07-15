import 'package:flutter/material.dart';
import 'l10n/strings.dart';
import 'note_colors.dart';

/// A starter template for a new note. Picking one on the "+" button pre-fills
/// the editor with a useful structure (a competitive gap vs. OneNote/Evernote,
/// tracked in qa-audit/COMPETITIVE_ROADMAP.md). Templates are seed content only
/// — the note is a completely normal note once created.
class NoteTemplate {
  final String id;
  final String name; // English fallback display name
  final String nameKey; // l10n key for the localized display name
  final IconData icon;
  final String type; // 'note' | 'checklist'
  final String title;
  final String body;
  final List<String> items;

  const NoteTemplate({
    required this.id,
    required this.name,
    required this.nameKey,
    required this.icon,
    this.type = 'note',
    this.title = '',
    this.body = '',
    this.items = const [],
  });

  /// True when the template carries no seed content (the plain "Blank note").
  bool get isBlank => title.isEmpty && body.isEmpty && items.isEmpty;
}

const NoteTemplate kBlankTemplate = NoteTemplate(
  id: 'blank',
  name: 'Blank note',
  nameKey: 'tpl_blank',
  icon: Icons.edit_outlined,
);

const List<NoteTemplate> kNoteTemplates = [
  NoteTemplate(
    id: 'todo',
    name: 'To-do list',
    nameKey: 'tpl_todo',
    icon: Icons.checklist_rtl,
    type: 'checklist',
    title: 'To-do',
    items: ['', '', ''],
  ),
  NoteTemplate(
    id: 'shopping',
    name: 'Shopping list',
    nameKey: 'tpl_shopping',
    icon: Icons.shopping_cart_outlined,
    type: 'checklist',
    title: 'Shopping',
    items: ['', '', ''],
  ),
  NoteTemplate(
    id: 'meeting',
    name: 'Meeting notes',
    nameKey: 'tpl_meeting',
    icon: Icons.groups_2_outlined,
    type: 'note',
    title: 'Meeting notes',
    body: 'Date: \nAttendees: \n\nAgenda\n- \n\nDiscussion\n- \n\nAction items\n- ',
  ),
  NoteTemplate(
    id: 'journal',
    name: 'Daily journal',
    nameKey: 'tpl_journal',
    icon: Icons.wb_sunny_outlined,
    type: 'note',
    title: 'Journal',
    body: 'How I feel\n\nHighlights\n- \n\nGrateful for\n- \n\nTomorrow\n- ',
  ),
  NoteTemplate(
    id: 'goals',
    name: 'Goal & plan',
    nameKey: 'tpl_goals',
    icon: Icons.flag_outlined,
    type: 'note',
    title: 'Goal',
    body: 'Objective\n\nWhy it matters\n\nSteps\n1. \n2. \n3. \n\nTarget date: ',
  ),
];

/// Shows the "start a note" sheet. Returns the chosen [NoteTemplate]
/// ([kBlankTemplate] for a plain note), or null if the user dismissed it.
Future<NoteTemplate?> showTemplatePicker(BuildContext context) {
  return showModalBottomSheet<NoteTemplate>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
              tr('start_note'),
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final t in [kBlankTemplate, ...kNoteTemplates])
            ListTile(
              leading: CircleAvatar(
                backgroundColor: kBrand.withValues(alpha: 0.12),
                foregroundColor: kBrand,
                child: Icon(t.icon),
              ),
              title: Text(tr(t.nameKey)),
              onTap: () => Navigator.pop(ctx, t),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
