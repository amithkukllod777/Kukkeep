import 'package:flutter/material.dart';
import '../api.dart';
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
  Future<void> _logout() async {
    await Notifications.instance.cancelAll(); // old account's reminders must not fire
    await Api.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
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
              title: Text(Api.instance.userName?.isNotEmpty == true ? Api.instance.userName! : 'KukLabs account'),
              subtitle: const Text('One KukLabs account across every Kuk app'),
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
                _TrustTile(Icons.lock_outline, 'Secure notes', 'Protected by your KukLabs account'),
                _TrustTile(Icons.visibility_off_outlined, 'Privacy focused', 'Your notes belong to you'),
                _TrustTile(Icons.cloud_done_outlined, 'Synced & backed up', 'Safe in the KukLabs cloud'),
                _TrustTile(Icons.block_outlined, 'Ad-free', 'No ads, no tracking — ever'),
              ]),
            ),
            const Divider(),
            const _Section('About'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('KukKeep'),
              subtitle: Text('Notes, lists & reminders • keep.kuklabs.com'),
            ),
            const ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('Version'),
              subtitle: Text('$kProductName $kAppVersion'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log out', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
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
