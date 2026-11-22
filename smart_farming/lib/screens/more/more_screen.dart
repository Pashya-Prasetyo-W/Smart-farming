import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../profile/profile_screen.dart';

class MoreItem {
  const MoreItem({
    required this.label,
    required this.icon,
    required this.builder,
    this.subtitle,
    this.color = AppColors.primary,
    this.badge = 0,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final int badge;
  final Widget Function() builder;
}

class MoreGroupData {
  const MoreGroupData({required this.title, required this.items});

  final String title;
  final List<MoreItem> items;
}

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, required this.groups});

  final List<MoreGroupData> groups;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _name = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString('name') ?? '';
      _role = prefs.getString('role') ?? '';
    });
  }

  String get _roleLabel {
    switch (_role) {
      case 'pemilik':
        return 'Pemilik';
      case 'mandor':
        return 'Mandor';
      case 'buruh':
        return 'Buruh';
      default:
        return '';
    }
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _profileCard() {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'T';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(const ProfileScreen()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.isEmpty ? 'Profil Saya' : _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleLabel.isEmpty
                          ? 'Lihat profil dan keluar'
                          : '$_roleLabel · Lihat profil dan keluar',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          _profileCard(),
          for (final group in widget.groups) ...[
            const SizedBox(height: AppSpacing.xl),
            MenuGroup(
              title: group.title,
              children: [
                for (final item in group.items)
                  MenuRow(
                    label: item.label,
                    subtitle: item.subtitle,
                    icon: item.icon,
                    color: item.color,
                    badge: item.badge,
                    onTap: () => _open(item.builder()),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
