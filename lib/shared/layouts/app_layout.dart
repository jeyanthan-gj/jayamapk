import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

class AppLayout extends StatelessWidget {
  final Widget child;
  const AppLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authService.user;
    final isAdmin = authService.isAdmin;
    String currentPath = '/';
    try {
      currentPath = GoRouterState.of(context).uri.path;
    } catch (_) {}
    final isDark = themeProvider.isDark;
    final screenWidth = MediaQuery.of(context).size.width;
    final showPermanentSidebar = screenWidth >= 768;

    final navItems = [
      {'path': '/', 'label': 'Dashboard', 'icon': LucideIcons.layoutDashboard},
      {'path': '/smartphones', 'label': 'Smartphones', 'icon': LucideIcons.smartphone},
      {'path': '/attendance', 'label': 'Attendance', 'icon': LucideIcons.mapPin},
      if (isAdmin) {'path': '/staff', 'label': 'Staff', 'icon': LucideIcons.users},
      if (isAdmin) {'path': '/users', 'label': 'Users', 'icon': LucideIcons.shieldCheck},
      {'path': '/profile', 'label': 'My Profile', 'icon': LucideIcons.user},
    ];

    Widget buildNavItem(Map<String, dynamic> item) {
      final path = item['path'] as String;
      final active = currentPath == path || (path != '/' && currentPath.startsWith(path));
      return GestureDetector(
        onTap: () {
          context.go(path);
          if (!showPermanentSidebar) Navigator.of(context).pop();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                item['icon'] as IconData,
                size: 18,
                color: active ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 12),
              Text(
                item['label'] as String,
                style: TextStyle(
                  color: active ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildSidebar() {
      return Container(
        width: 240,
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('assets/brand-logo.jpg', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Jayam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                      Text('MOBILES', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 2)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 8),
            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: navItems.map(buildNavItem).toList(),
              ),
            ),
            const Divider(color: Color(0xFF334155), height: 1),
            // User section at bottom
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    radius: 18,
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'User',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text((user?.role ?? 'staff').toUpperCase(),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                      ],
                    ),
                  ),
                  // Theme toggle
                  GestureDetector(
                    onTap: () => context.read<ThemeProvider>().toggleTheme(),
                    child: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, size: 18, color: const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(width: 12),
                  // Logout
                  GestureDetector(
                    onTap: () => _showLogoutConfirmation(context, authService),
                    child: const Icon(LucideIcons.logOut, size: 18, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (showPermanentSidebar) {
      // Desktop: permanent sidebar + content side by side
      return Scaffold(
        body: Row(
          children: [
            buildSidebar(),
            // Thin vertical divider
            Container(width: 1, color: const Color(0xFF334155)),
            // Main content area
            Expanded(
              child: Column(
                children: [
                  // Top bar (minimal — just theme toggle + logout on mobile. On Desktop the sidebar has them)
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Logout button styled like React
                        OutlinedButton.icon(
                          icon: const Icon(LucideIcons.logOut, size: 14),
                          label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showLogoutConfirmation(context, authService),
                        ),
                        const SizedBox(width: 12),
                        // Theme toggle
                        IconButton(
                          icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, size: 20),
                          onPressed: () => context.read<ThemeProvider>().toggleTheme(),
                          tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile: drawer-based layout
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/brand-logo.jpg', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Jayam Mobiles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon),
              onPressed: () => context.read<ThemeProvider>().toggleTheme(),
            ),
            IconButton(
              icon: const Icon(LucideIcons.logOut, color: AppTheme.primary),
              onPressed: () => _showLogoutConfirmation(context, authService),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: const Color(0xFF0F172A),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset('assets/brand-logo.jpg', fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Jayam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                          Text('MOBILES', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 2)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF334155)),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: navItems.map(buildNavItem).toList(),
                  ),
                ),
                const Divider(color: Color(0xFF334155)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primary,
                        radius: 18,
                        child: Text(user?.name.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(user?.name ?? 'User', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text((user?.role ?? 'staff').toUpperCase(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showLogoutConfirmation(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              authService.signOut();
              context.go('/login');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
