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
}
