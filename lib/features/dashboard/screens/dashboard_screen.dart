import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _brandsCount = 0;
  int _modelsCount = 0;
  int _staffCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final isAdmin = context.read<AuthService>().isAdmin;
    final client = Supabase.instance.client;

    try {
      final brandsRes = await client.from('brands').select('id').count(CountOption.exact);
      final modelsRes = await client.from('models').select('id').count(CountOption.exact);
      int staffCount = 0;
      
      if (isAdmin) {
        final staffRes = await client.from('staff').select('id').count(CountOption.exact);
        staffCount = staffRes.count;
      }

      if (mounted) {
        setState(() {
          _brandsCount = brandsRes.count;
          _modelsCount = modelsRes.count;
          _staffCount = staffCount;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.75))),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _loading ? '—' : value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final isAdmin = context.watch<AuthService>().isAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text.rich(
            TextSpan(
              text: 'Welcome, ',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              children: [
                TextSpan(
                  text: user?.name ?? 'User',
                  style: const TextStyle(color: AppTheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Here\'s your shop overview', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7))),
          const SizedBox(height: 32),

          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 500 ? 1 : (constraints.maxWidth < 900 ? 2 : 4);
              final spacing = 16.0;
              final cardWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
              final cards = [
                _buildStatCard(title: 'Total Brands', value: _brandsCount.toString(), icon: LucideIcons.package, iconBgColor: AppTheme.primary),
                _buildStatCard(title: 'Total Models', value: _modelsCount.toString(), icon: LucideIcons.smartphone, iconBgColor: const Color(0xFF0EA5E9)),
                if (isAdmin) _buildStatCard(title: 'Staff Members', value: _staffCount.toString(), icon: LucideIcons.users, iconBgColor: AppTheme.primary),
                _buildStatCard(title: 'Role', value: (user?.role ?? '').toUpperCase(), icon: LucideIcons.trendingUp, iconBgColor: const Color(0xFF0EA5E9)),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
              );
            },
          ),
          const SizedBox(height: 32),

          // Quick Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth < 500 ? 2 : 4;
                  final spacing = 16.0;
                  final tileWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                  final tiles = [
                    _buildQuickAction(title: 'Browse Phones', icon: LucideIcons.smartphone, iconColor: AppTheme.primary, onTap: () => context.go('/smartphones')),
                    if (isAdmin) ...[
                      _buildQuickAction(title: 'Add Model', icon: LucideIcons.package, iconColor: const Color(0xFF0EA5E9), onTap: () => context.go('/smartphones')),
                      _buildQuickAction(title: 'Manage Staff', icon: LucideIcons.users, iconColor: AppTheme.primary, onTap: () => context.go('/staff')),
                      _buildQuickAction(title: 'Manage Users', icon: LucideIcons.shield, iconColor: const Color(0xFF0EA5E9), onTap: () => context.go('/users')),
                    ],
                  ];
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: tiles.map((t) => SizedBox(width: tileWidth, height: 110, child: t)).toList(),
                  );
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
