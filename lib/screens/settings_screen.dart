import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../auth_messages.dart';
import '../main.dart';
import '../notifications.dart';
import '../note_colors.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;
  bool _deleting = false;

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

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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

  // Account deletion (auth.deleteMyAccount) — Google Play requires an in-app
  // path for apps with in-app account creation; see qa-audit/PRODUCTION_READINESS_CHECKLIST.md.
  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
          'This permanently anonymizes your Kuklabs account and removes your '
          'access to it. Notes and other content tied to a shared workspace '
          'may be retained where required by law. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account', style: TextStyle(color: Colors.red))),
      ]));
    if (ok != true) return;
    setState(() => _deleting = true);
    try {
      await Notifications.instance.cancelAll();
      await Api.instance.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
    } catch (e) {
      // e.g. "you still own a company — transfer ownership first" — the
      // server's own message here is already actionable, not technical.
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: kBrand, foregroundColor: Colors.white),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, mode, __) => ListView(
          children: [
            const _Section('Account'),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined, color: kBrand),
              title: Text(Api.instance.userName?.isNotEmpty == true ? Api.instance.userName! : 'Kuklabs account'),
              subtitle: const Text('One Kuklabs account across every Kuk app'),
            ),
            const Divider(),
            const _Section('Theme'),
            RadioListTile<ThemeMode>(
              value: ThemeMode.system, groupValue: mode, activeColor: kBrand,
              title: const Text('System default'), onChanged: (m) => setThemeMode(m!)),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light, groupValue: mode, activeColor: kBrand,
              title: const Text('Light'), onChanged: (m) => setThemeMode(m!)),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark, groupValue: mode, activeColor: kBrand,
              title: const Text('Dark'), onChanged: (m) => setThemeMode(m!)),
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
            const _Section('Data & Privacy'),
            ListTile(
              leading: _exporting
                  ? const SizedBox(width: 22, height: 22, child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2, color: kBrand)))
                  : const Icon(Icons.download_outlined, color: kBrand),
              title: const Text('Export my data'),
              subtitle: const Text('Download your Kuklabs account data'),
              onTap: _exporting ? null : _exportData,
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: kBrand),
              title: const Text('Terms of Use'),
              onTap: () => _open('https://kuklabs.com/terms'),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: kBrand),
              title: const Text('Privacy Policy'),
              onTap: () => _open('https://kuklabs.com/privacy'),
            ),
            const Divider(),
            const _Section('About'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(kProductName),
              subtitle: Text('Notes, lists & reminders • $kWebsite'),
            ),
            const ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('Version'),
              // KUKLABS_BRAND_CONFIG.json versionDisplayFormat: "Version {version} (Build {build})"
              subtitle: Text('Version $kAppVersion (Build $kAppBuild)'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log out', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
            const Divider(),
            const _Section('Danger Zone'),
            ListTile(
              leading: _deleting
                  ? const SizedBox(width: 22, height: 22, child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)))
                  : const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete account', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Permanently delete your Kuklabs account'),
              onTap: _deleting ? null : _deleteAccount,
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
