import 'package:flutter/material.dart';

/// KukKeep note background colors (mirrors the web app's 8 Keep-style colors).
const Map<String, Color> kNoteColors = {
  'default': Color(0xFFFFFFFF),
  'amber': Color(0xFFFFF8E1),
  'blue': Color(0xFFE3F2FD),
  'green': Color(0xFFE8F5E9),
  'rose': Color(0xFFFFEBEE),
  'purple': Color(0xFFF3E5F5),
  'cyan': Color(0xFFE0F7FA),
  'slate': Color(0xFFECEFF1),
};

const List<String> kColorKeys = [
  'default', 'amber', 'blue', 'green', 'rose', 'purple', 'cyan', 'slate',
];

Color noteColor(String key) => kNoteColors[key] ?? kNoteColors['default']!;

// ── KukKeep product accent (KUKLABS_IDENTITY.md §4 productBrand) ──
// accent-600 = #2868F0 for KukKeep; the shared standard mandates a per-product
// accent used only for primary actions, selected states, links and focus.
const Color kBrand = Color(0xFF2868F0);      // accent-600 (KukKeep)
const Color kBrandDark = Color(0xFF1D4ED8);  // accent-700 (gradients / pressed)
const Color kBrandLight = Color(0xFF5B8CFF); // accentDark (dark-mode accent)
const Color kBrandNavy = Color(0xFF1E293B);  // logo navy
const Color kBrandViolet = Color(0xFF7C3AED); // logo violet accent

// ── Shared neutral + semantic tokens (KUKLABS_IDENTITY.md §6, §5.6) ──
const Color kBg = Color(0xFFF8FAFC);          // app background
const Color kSurface = Color(0xFFFFFFFF);     // surface
const Color kSurface2 = Color(0xFFF2F4F7);    // surface secondary
const Color kTextPrimary = Color(0xFF101828);
const Color kTextSecondary = Color(0xFF475467);
const Color kTextMuted = Color(0xFF667085);
const Color kPlaceholder = Color(0xFF98A2B3);
const Color kBorder = Color(0xFFD0D5DD);
const Color kBorderSubtle = Color(0xFFEAECF0);
const Color kError = Color(0xFFD92D20);       // semantic error (destructive/errors only)
const Color kSuccess = Color(0xFF039855);
const Color kWarning = Color(0xFFDC6803);

// Primary UI font (KUKLABS_IDENTITY.md §5.1 — Inter, falling back to the
// platform sans; serif is not used in product UI per §5.7).
const String kFont = 'Inter';
const String kWebBase = 'https://keep.kuklabs.com';

// Brand assets + identity (docs/kuklabs/KUKLABS_BRAND_CONFIG.json).
const String kLogoAsset = 'assets/logo.png';
const String kProductName = 'Kuk Keep';
const String kShortName = 'Keep';
const String kWebsite = 'keep.kuklabs.com';
const String kTermsUrl = 'https://kuklabs.com/terms';
const String kPrivacyUrl = 'https://kuklabs.com/privacy';
const String kSupportUrl = 'https://kuklabs.com/support';
// App version shown in Settings → About as "Version x.y.z (Build n)"
// (KUKLABS_MASTER_STANDARD.md §12.2). Keep in sync with pubspec `version`.
const String kAppVersion = '2.5.1';
const int kAppBuild = 41;

// Display headings share the primary sans family (no serif in product UI).
const String kDisplayFont = kFont;
const Color kHighlight = Color(0xFFFFF176); // search-match highlight
const Color kCardShadow = Color(0x14000000); // soft card drop shadow
