import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'section_page.dart';
import 'settings_screen.dart';
import 'work_requests_screen.dart';

/// Who is signed in, and the things that are not part of the day-to-day cards: the work requests, the transaction history, the
/// server address and the log out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  MeInfo? _me;
  String _name = '';
  String _subtitle = '';

  @override
  void initState() {
    super.initState();
    _showSavedUser();
    _load();
  }

  Future<void> _showSavedUser() async {
    final saved = await AuthService.getUserData();
    if (!mounted) return;
    final position = (saved['position'] ?? '').toString();
    final branch = (saved['branch'] ?? '').toString();
    setState(() {
      _name = (saved['fullName'] ?? '').toString();
      _subtitle = [position, branch].where((part) => part.isNotEmpty).join(' · ');
    });
  }

  Future<void> _load() async {
    final result = await FieldService.me();
    if (!mounted) return;
    final me = result.me;
    setState(() {
      _me = me;
      if (me != null) {
        _name = me.fullName;
        _subtitle = [me.position, me.branch].where((part) => part.isNotEmpty).join(' · ');
      }
    });
  }

  Future<void> _push(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Do you want to log out from this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final attention = _me?.needsAttention ?? 0;
    final initial = _name.trim().isEmpty ? '?' : _name.trim()[0].toUpperCase();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Center(
            child: Text(
              'Profile',
              style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Text(
                initial,
                style: const TextStyle(color: AppColors.primary, fontSize: 32, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _name.isEmpty ? 'Employee' : _name,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          if (_subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Center(
                child: Text(
                  _subtitle,
                  style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FeatureCard(
            icon: Icons.assignment_outlined,
            title: 'My work requests',
            subtitle: attention > 0 ? '$attention need your attention' : 'Installation and repair requests',
            badge: attention > 0 ? '$attention' : null,
            onTap: () => _push(const WorkRequestsScreen()),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.history,
            title: 'Transaction history',
            subtitle: 'Item out, item return, installation and repair',
            onTap: () => _push(const SectionPage(title: 'Transaction History', child: HistoryScreen())),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.settings_outlined,
            title: 'Server settings',
            subtitle: 'The address of the JFTECH server',
            onTap: () => _push(const SettingsScreen()),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
