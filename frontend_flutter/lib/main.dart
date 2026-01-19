import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/esc_provider.dart';
import 'ui/theme/app_theme.dart';
import 'ui/components/modern_components.dart';
import 'ui/screens/wizard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/profile_screen.dart';
import 'services/session_manager.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ESCProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESC Configurator',
      debugShowCheckedModeBanner: false,
      theme: AppThemeData.lightTheme(),
      darkTheme: AppThemeData.darkTheme(),
      themeMode: ThemeMode.system,
      home: const AuthGateway(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const WizardMainScreen(),
      },
    );
  }
}

/// Authentication Gateway
/// Route users to login/signup or main app based on auth status
class AuthGateway extends StatefulWidget {
  const AuthGateway({Key? key}) : super(key: key);

  @override
  State<AuthGateway> createState() => _AuthGatewayState();
}

class _AuthGatewayState extends State<AuthGateway> {
  bool? _isAuthenticated; // null = loading
  int _currentTab = 0; // 0: Login, 1: Signup

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await SessionManager.isLoggedIn();
    if (mounted) {
      setState(() {
        _isAuthenticated = isLoggedIn;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isAuthenticated == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Already authenticated
    if (_isAuthenticated!) {
      return const WizardMainScreen();
    }

    // Not authenticated - show login/signup
    return Scaffold(
      body: _currentTab == 0
          ? LoginScreen(
              // Navigate to signup
            )
          : SignUpScreen(
              onSignupSuccess: () {
                setState(() => _currentTab = 0);
              },
            ),
    );
  }
}

/// Main Application Screen
/// Modern tab-based navigation for ESC configuration
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Legacy - Use WizardMainScreen from wizard_screen.dart instead
class TabItem {
  final IconData icon;
  final String label;
  final Widget screen;

  TabItem({
    required this.icon,
    required this.label,
    required this.screen,
  });
}
