import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/field_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'attendance_screen.dart';
import 'inventory_screen.dart';
import 'nap_boxes_screen.dart';
import 'section_page.dart';
import 'work_requests_screen.dart';

/// The start page after login: a greeting and the three things the employee does every day. Each card opens its own page.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MeInfo? _me;
  String _name = '';
  String _subtitle = '';
  bool _loading = true;

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
    if (me != null) {
      // The server knows the branch best (an admin may have moved the employee).
      if (me.branch.isNotEmpty) AuthService.saveBranch(me.branch);
      _name = me.fullName;
      _subtitle = [me.position, me.branch].where((part) => part.isNotEmpty).join(' · ');
    }
    setState(() {
      _me = me;
      _loading = false;
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _openRequests() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkRequestsScreen()));
    _load();
  }

  /// Opens one of the cards as its own page, and refreshes the Home when the employee comes back (the day may have changed).
  Future<void> _open(String title, Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SectionPage(title: title, child: screen)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final attention = _me?.needsAttention ?? 0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting,',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _name.isEmpty ? 'Employee' : _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_subtitle.isNotEmpty)
                      Text(
                        _subtitle,
                        style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Work requests',
                    onPressed: _openRequests,
                    icon: const Icon(Icons.notifications_none, color: AppColors.text),
                  ),
                  if (attention > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$attention',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stay productive,\nyou\'re doing great!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _loading
                            ? 'Loading your day…'
                            : (_me?.today.onDuty == true
                                ? 'You are on duty. Have a safe day in the field.'
                                : 'Check in to start your day.'),
                        style: const TextStyle(color: Color(0xFFCFE0FB), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: Color(0x26FFFFFF), shape: BoxShape.circle),
                  child: const Icon(Icons.cell_tower, color: Colors.white, size: 38),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FeatureCard(
            icon: Icons.fingerprint,
            title: 'Attendance',
            subtitle: 'Check in and out',
            onTap: () => _open('Attendance', const AttendanceScreen()),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.inventory_2_outlined,
            title: 'Inventory',
            subtitle: 'View and record items',
            badge: _me != null && _me!.pendingInventory > 0 ? '${_me!.pendingInventory} pending' : null,
            onTap: () => _open('Inventory', const InventoryScreen()),
          ),
          const SizedBox(height: 12),
          FeatureCard(
            icon: Icons.router_outlined,
            title: 'NAP Box Monitoring',
            subtitle: 'Check NAP boxes and ports',
            onTap: () => _open('NAP Box Monitoring', const NapBoxesScreen()),
          ),
        ],
      ),
    );
  }
}
