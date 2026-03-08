import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/auth/auth_service.dart';
import 'shared/layouts/app_layout.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/attendance/screens/attendance_screen.dart';
import 'features/staff/screens/staff_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/smartphones/screens/smartphones_screen.dart';
import 'features/smartphones/screens/smartphone_detail_screen.dart';
import 'features/users/screens/user_management_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://egocyaqothxccsehhlvg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnb2N5YXFvdGh4Y2NzZWhobHZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1NjM5NDIsImV4cCI6MjA4ODEzOTk0Mn0.it8QzJeRWm4cqvEeZNoOfqJsOyzT_-kEikTukfpTbxg',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const JayamMobilesApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/login',
  refreshListenable: AuthService.instance,
  redirect: (context, state) {
    final authService = AuthService.instance;
    final loggingIn = state.uri.path == '/login';

    if (authService.loading) return null;
    if (authService.user == null) return loggingIn ? null : '/login';
    if (loggingIn) return '/';

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppLayout(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/smartphones',
          builder: (context, state) => const SmartphonesScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return SmartphoneDetailScreen(id: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/attendance',
          builder: (context, state) => const AttendanceScreen(),
        ),
        GoRoute(
          path: '/staff',
          builder: (context, state) => const StaffScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);

class JayamMobilesApp extends StatelessWidget {
  const JayamMobilesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp.router(
      title: 'Jayam Mobiles Manager',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}


class DummyScreen extends StatelessWidget {
  final String title;
  const DummyScreen(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title Content Here', style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
