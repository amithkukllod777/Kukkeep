import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kukkeep/l10n/strings.dart';
import 'package:kukkeep/note_templates.dart';

// Unit tests for the map-based localization + note templates. These don't need
// a Flutter binding: tr() only reads LocaleController's in-memory default.
void main() {
  group('localization', () {
    test('tr resolves the default (English) locale', () {
      expect(tr('settings'), 'Settings');
      expect(tr('notes'), 'Note');
      expect(tr('language'), 'Language');
    });

    test('tr returns the key itself for an unknown key', () {
      expect(tr('__missing_key__'), '__missing_key__');
    });

    test('tr resolves keys from the secondary (_extra) table too', () {
      expect(tr('notifications'), 'Notifications');
      expect(tr('reminders'), 'Reminders');
      expect(tr('save'), 'Save');
      expect(tr('verify'), 'Verify');
      expect(tr('manage_account'), 'Manage account');
    });

    test('a broad set of languages is offered', () {
      expect(kSupportedLangs.length, greaterThanOrEqualTo(10));
      expect(kSupportedLangs.first.code, 'en');
      // every supported locale maps 1:1 to a language entry
      expect(kSupportedLocales.length, kSupportedLangs.length);
    });
  });

  group('note templates', () {
    test('every template resolves a real localized name', () {
      for (final t in [kBlankTemplate, ...kNoteTemplates]) {
        expect(tr(t.nameKey), isNot(t.nameKey), reason: 'missing en for ${t.nameKey}');
      }
    });

    test('the blank template carries no seed content', () {
      expect(kBlankTemplate.isBlank, isTrue);
    });

    test('content templates actually seed something', () {
      for (final t in kNoteTemplates) {
        expect(t.isBlank, isFalse, reason: t.id);
      }
    });
  });

  group('newer feature strings', () {
    tearDown(() => LocaleController.locale.value = const Locale('en'));

    test('filters / share / export / version-history keys resolve in English', () {
      expect(tr('filters'), 'Filters');
      expect(tr('filter_reminder'), 'Has reminder');
      expect(tr('filter_attachment'), 'Has attachment');
      expect(tr('share'), 'Share');
      expect(tr('export_notes'), 'Export notes');
      expect(tr('version_history'), 'Version history');
      expect(tr('restore'), 'Restore');
    });

    test('these keys are actually translated (not English fallback) for hi/ja', () {
      LocaleController.locale.value = const Locale('hi');
      expect(tr('filters'), 'फ़िल्टर');
      expect(tr('share'), 'साझा करें');
      expect(tr('version_history'), 'संस्करण इतिहास');

      LocaleController.locale.value = const Locale('ja');
      expect(tr('restore'), '復元');
      expect(tr('export_notes'), 'メモをエクスポート');
    });

    test('every supported language resolves the new keys to a real string', () {
      for (final lang in kSupportedLangs) {
        LocaleController.locale.value = Locale(lang.code);
        for (final key in ['filters', 'share', 'export_notes', 'version_history', 'restore']) {
          final v = tr(key);
          expect(v, isNotEmpty, reason: '$key empty for ${lang.code}');
          expect(v, isNot(key), reason: '$key unresolved for ${lang.code}');
        }
      }
    });
  });
}
