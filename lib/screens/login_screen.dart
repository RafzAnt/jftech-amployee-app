import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'main_shell.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  /// A message to show on top of the form, for example that the session ended.
  final String? notice;

  const LoginScreen({super.key, this.notice});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Enter your username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainShell()),
      );
    } else {
      setState(() => _errorMessage = result['message']?.toString() ?? 'Could not sign in.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 8, 24, 80),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.navy, AppColors.primary],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                      tooltip: 'Server settings',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ),
                  // The logo is drawn for a dark background (its ring and its lettering are white), so it sits straight on the blue.
                  Image.asset(
                    'assets/images/jftech_logo.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'JFTECH',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'CONNECTING COMMUNITIES',
                    style: TextStyle(fontSize: 11, color: Color(0xFFBBD0F2), letterSpacing: 2),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AppCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Employee Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sign in to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                      if (notice != null && notice.isNotEmpty && _errorMessage == null)
                        Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            notice,
                            style: const TextStyle(color: AppColors.primaryDark, fontSize: 13),
                          ),
                        ),
                      if (_errorMessage != null) FormError(_errorMessage!),
                      const FieldLabel('Username'),
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                        decoration: const InputDecoration(
                          hintText: 'Username or Employee ID',
                          prefixIcon: Icon(Icons.person_outline, color: AppColors.muted),
                        ),
                      ),
                      const FieldLabel('Password'),
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.muted,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton(label: 'Login', loading: _isLoading, onPressed: _login),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 28),
              child: Text(
                'Better Connection. Brighter Future.',
                style: TextStyle(color: AppColors.muted, fontSize: 12, letterSpacing: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
