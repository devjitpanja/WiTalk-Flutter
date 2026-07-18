import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Settings', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)), leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop())),
      body: ListView(children: [
        _section('Appearance', [
          SwitchListTile(value: isDark, onChanged: (_) => ref.read(themeProvider.notifier).toggle(), title: const Text('Dark Mode', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')), activeColor: AppColors.primaryButton),
        ]),
        _section('Privacy', [
          _tile(Icons.notifications_outlined, 'Notifications', () => context.push('/settings/notifications')),
          _tile(Icons.lock_outline, 'Message Privacy', () => context.push('/settings/message-privacy')),
          _tile(Icons.filter_list, 'Content Preferences', () => context.push('/settings/content')),
          _tile(Icons.block, 'Blocked Accounts', () => context.push('/blocked-accounts')),
        ]),
        _section('Storage', [
          _tile(Icons.storage_outlined, 'Storage & Data', () => context.push('/settings/storage')),
        ]),
        _section('Account', [
          _tile(Icons.person_outline, 'Account', () => context.push('/account-settings')),
          _tile(Icons.logout, 'Sign Out', () => ref.read(authProvider.notifier).signOut(), color: AppColors.error),
        ]),
      ]),
    );
  }
  Widget _section(String title, List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8), child: Text(title, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Outfit', letterSpacing: 0.8))), ...items]);
  Widget _tile(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(leading: Icon(icon, color: color ?? AppColors.textSecondary, size: 22), title: Text(label, style: TextStyle(color: color ?? Colors.white, fontFamily: 'Outfit', fontSize: 15)), trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18), onTap: onTap, dense: true);
}