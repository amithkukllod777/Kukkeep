import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../auth_messages.dart';
import '../l10n/strings.dart';
import '../main.dart';
import '../models.dart';
import '../notifications.dart';
import '../note_colors.dart';
import 'auth_screen.dart';
import 'notes_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;
  bool _switchingWorkspace = false;

  Future<void> _logout() async {
    await Notifications.instance.cancelAll(); // old account's reminders must not fire
    await Api.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
  }

  Future<void> _open(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
  }

  // Language picker (multi-language support). Persists via LocaleController;
  // MaterialApp is wrapped in a listener on it, so the whole app re-renders.
  Future<void> _pickLanguage() async {
    final current = LocaleController.locale.value.languageCode;
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(tr('language'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            for (final l in kSupportedLangs)
              ListTile(
                title: Text(l.native),
                subtitle: Text(l.english),
                trailing: l.code == current ? const Icon(Icons.check, color: kBrand) : null,
                onTap: () => Navigator.pop(context, l.code),
              ),
          ],
        ),
      ),
    );
    if (code != null) {
      await LocaleController.set(code);
      if (mounted) setState(() {});
    }
  }

  String get _currentLangNative => kSupportedLangs
      .firstWhere((l) => l.code == LocaleController.locale.value.languageCode,
          orElse: () => kSupportedLangs.first)
      .native;

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // BUG-011: the workspace picker only ever appeared once, right after login
  // (auth_screen.dart's _pickCompany) — multi-workspace users had no way back
  // into it. Reuses the same list-and-pick UI, then reloads NotesScreen fresh
  // (like auth_screen's _goToNotes) so the note list reflects the new company.
  Future<void> _switchWorkspace() async {
    setState(() => _switchingWorkspace = true);
    List<Company> companies;
    try {
      companies = await Api.instance.companies();
    } catch (e) {
      if (mounted) { setState(() => _switchingWorkspace = false); _snack(friendlyError(e)); }
      return;
    }
    if (!mounted) return;
    setState(() => _switchingWorkspace = false);
    if (companies.length <= 1) { _snack('You only have one workspace.'); return; }
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(padding: EdgeInsets.all(16),
            child: Text('Switch workspace', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          for (final c in companies)
            ListTile(
              leading: Icon(Icons.business, color: c.id == Api.instance.companyId ? kBrand : Colors.black38),
              title: Text(c.name),
              trailing: c.id == Api.instance.companyId ? const Icon(Icons.check, color: kBrand) : null,
              onTap: () => Navigator.pop(context, c.id),
            ),
        ],
      ),
    );
    if (picked == null || picked == Api.instance.companyId) return;
    Api.instance.setCompany(picked);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const NotesScreen()), (r) => false);
  }

  // GDPR/DPDP data export (auth.exportMyData) — see qa-audit/REMEDIATION_PLAN.md.
  Future<void> _exportData() async {
    setState(() => _exporting = true);
    try {
      final data = await Api.instance.exportMyData();
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => AlertDialog(
        title: const Text('Your account data'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(pretty, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
        ),
        actions: [
          TextButton(
            onPressed: () { Clipboard.setData(ClipboardData(text: pretty)); _snack('Copied to clipboard'); },
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ));
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings')), backgroundColor: kBrand, foregroundColor: Colors.white),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, mode, __) => ListView(
          children: [
            _Section(tr('account')),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined, color: kBrand),
              title: Text(Api.instance.userName?.isNotEmpty == true ? Api.instance.userName! : 'Kuklabs account'),
              subtitle: const Text('One Kuklabs account across every Kuk app'),
            ),
            ListTile(
              leading: _switchingWorkspace
                  ? const SizedBox(width: 22, height: 22, child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2, color: kBrand)))
                  : const Icon(Icons.business_outlined, color: kBrand),
              title: Text(tr('workspace')),
              subtitle: Text(tr('workspace_sub')),
              onTap: _switchingWorkspace ? null : _switchWorkspace,
            ),
            ListTile(
              leading: const Icon(Icons.language, color: kBrand),
              title: Text(tr('language')),
              subtitle: Text(tr('language_sub')),
              trailing: Text(_currentLangNative, style: const TextStyle(color: Colors.black54)),
              onTap: _pickLanguage,
            ),
            const Divider(),
            _Section(tr('theme')),
            RadioListTile<ThemeMode>(
              value: ThemeMode.system, groupValue: mode, activeColor: kBrand,
              title: Text(tr('system_default')), onChanged: (m) => setThemeMode(m!)),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light, groupValue: mode, activeColor: kBrand,
              title: Text(tr('light')), onChanged: (m) => setThemeMode(m!)),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark, groupValue: mode, activeColor: kBrand,
              title: Text(tr('dark')), onChanged: (m) => setThemeMode(m!)),
            const Divider(),
            _Section(tr('notifications')),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined, color: kBrand),
              title: Text(tr('reminders')),
              subtitle: Text(tr('reminders_sub')),
              value: Notifications.instance.remindersEnabled,
              activeColor: kBrand,
              onChanged: (v) async {
                await Notifications.instance.setRemindersEnabled(v);
                if (mounted) setState(() {});
              },
            ),
            const Divider(),
            const _Section('Privacy & Trust'),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                _TrustTile(Icons.lock_outline, 'Secure notes', 'Protected by your Kuklabs account'),
                _TrustTile(Icons.visibility_off_outlined, 'Privacy focused', 'Your notes belong to you'),
                _TrustTile(Icons.cloud_done_outlined, 'Synced & backed up', 'Safe in the Kuklabs cloud'),
                _TrustTile(Icons.block_outlined, 'Ad-free', 'No ads, no tracking — ever'),
              ]),
            ),
            const Divider(),
            _Section(tr('data_privacy')),
            ListTile(
              leading: _exporting
                  ? const SizedBox(width: 22, height: 22, child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2, color: kBrand)))
                  : const Icon(Icons.download_outlined, color: kBrand),
              title: Text(tr('export_data')),
              subtitle: Text(tr('export_data_sub')),
              onTap: _exporting ? null : _exportData,
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: kBrand),
              title: Text(tr('terms')),
              onTap: () => _open('https://kuklabs.com/terms'),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: kBrand),
              title: Text(tr('privacy_policy')),
              onTap: () => _open('https://kuklabs.com/privacy'),
            ),
            const Divider(),
            _Section(tr('about')),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(kProductName),
              subtitle: Text('Notes, lists & reminders • $kWebsite'),
            ),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(tr('version')),
              // KUKLABS_BRAND_CONFIG.json versionDisplayFormat: "Version {version} (Build {build})"
              subtitle: const Text('Version $kAppVersion (Build $kAppBuild)'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(tr('log_out'), style: const TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
            const Divider(),
            // Account management (incl. deletion) lives on the web — Google Play's
            // Account Deletion policy is satisfied by this clearly-labelled path
            // plus the same URL declared in the Play Console Data Safety form.
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined, color: kBrand),
              title: Text(tr('manage_account')),
              subtitle: Text(tr('manage_account_sub')),
              onTap: () => _open('https://kuklabs.com/account'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Small rounded "trust" tile (reference privacy-grid design), two per row.
class _TrustTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _TrustTile(this.icon, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final w = (MediaQuery.of(context).size.width - 42) / 2;
    return Container(
      width: w,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? Colors.white12 : Colors.black.withOpacity(0.06)),
        boxShadow: dark ? null : const [BoxShadow(color: kCardShadow, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: kBrand),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 11, color: dark ? Colors.white60 : Colors.black54)),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kBrand, letterSpacing: 0.5)),
      );
}
