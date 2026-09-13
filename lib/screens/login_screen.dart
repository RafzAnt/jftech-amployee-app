import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'inventory_request_screen.dart';
import 'scanner_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
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

    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } else {
      setState(() => _errorMessage = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14161C),
      body: Container(
        color: const Color(0xFF14161C),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Color(0xFF8A8D94)),
                  tooltip: 'Server settings',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Image.asset(
                  'assets/images/jftech_logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                const Text(
                  'JFTECH',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4C7EDB),
                    letterSpacing: 2.5,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Employee App',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8D94),
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 56),
                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.1),
                      border: Border.all(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFFF1744), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFFF1744), fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Username
                TextField(
                  controller: _usernameController,
                  focusNode: _usernameFocusNode,
                  cursorColor: const Color(0xFF4C7EDB),
                  style: const TextStyle(color: Color(0xFFE6E7EA)),
                  decoration: _fieldDecoration('Username', Icons.person_outline),
                ),
                const SizedBox(height: 16),
                // Password
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: true,
                  cursorColor: const Color(0xFF4C7EDB),
                  style: const TextStyle(color: Color(0xFFE6E7EA)),
                  decoration: _fieldDecoration('Password', Icons.lock_outline),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 32),
                // Login button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C7EDB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Contact admin for account creation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8A8D94),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    const borderColor = Color(0xFF2C2F38);
    const accentColor = Color(0xFF4C7EDB);
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF8A8D94)),
      floatingLabelStyle: const TextStyle(color: accentColor),
      prefixIcon: Icon(icon, color: const Color(0xFF8A8D94), size: 21),
      filled: true,
      fillColor: const Color(0xFF1A1C23),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
        borderSide: BorderSide(color: accentColor),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Do you want to log out from this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true), child: const Text('Log out')),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14161C),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ScannerScreen(),
          InventoryRequestScreen(),
          HistoryScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF14161C),
              border: Border(top: BorderSide(color: Color(0xFF22252E))),
            ),
            child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 3) {
              _logout();
              return;
            }
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF4C7EDB),
          unselectedItemColor: const Color(0xFF8A8D94),
          type: BottomNavigationBarType.fixed,
          items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner_outlined),
                label: 'Scan QR',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'Inventory',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_outlined),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.logout_outlined),
                label: 'Logout',
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
