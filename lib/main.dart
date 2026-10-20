import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initBaseUrl();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const JFTechApp());
}

class JFTechApp extends StatefulWidget {
  const JFTechApp({super.key});

  @override
  State<JFTechApp> createState() => _JFTechAppState();
}

class _JFTechAppState extends State<JFTechApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // When the server no longer accepts the sign-in (it ended, or the account was turned off), go to the login.
    ApiClient.onUnauthorized = () => _signOut(message: 'Your session has ended. Please sign in again.');
  }

  @override
  void dispose() {
    ApiClient.onUnauthorized = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      AuthService.markAppInBackground();
    } else if (state == AppLifecycleState.resumed) {
      _signOutWhenSessionExpires();
    }
  }

  Future<void> _signOutWhenSessionExpires() async {
    if (_signingOut || !await AuthService.hasSessionExpired()) return;
    await _signOut();
  }

  Future<void> _signOut({String? message}) async {
    if (_signingOut) return;
    _signingOut = true;
    await AuthService.logout();
    final navigator = _navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(notice: message)),
        (route) => false,
      );
    }
    _signingOut = false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'JFTECH',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final hasExpired = await AuthService.hasSessionExpired();
    if (hasExpired) await AuthService.logout();
    final isLoggedIn = !hasExpired && await AuthService.isLoggedIn();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => isLoggedIn ? const MainShell() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navy, AppColors.primaryDark],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The logo is drawn for a dark background (its ring and its lettering are white), so it sits straight on the blue.
              Image.asset(
                'assets/images/jftech_logo.png',
                width: 170,
                height: 170,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              const Text(
                'JFTECH',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'CONNECTING COMMUNITIES',
                style: TextStyle(fontSize: 11, color: Color(0xFFBBD0F2), letterSpacing: 2),
              ),
              const SizedBox(height: 44),
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
