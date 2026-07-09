import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../providers/app_state.dart';
import '../utils/password_validator.dart';
import 'server_settings_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  final _regUsername = TextEditingController();
  final _resetEmail = TextEditingController();
  final _resetToken = TextEditingController();
  final _resetPassword = TextEditingController();
  bool _loading = false;
  bool _showReset = false;
  String? _emailError;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    _regUsername.dispose();
    _resetEmail.dispose();
    _resetToken.dispose();
    _resetPassword.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    context.read<AppState>().clearError();
    await action();
    if (mounted) setState(() => _loading = false);
  }

  void _openServerSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final pwValidation = validatePassword(_regPassword.text);

    if (_showReset) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _resetEmail,
                decoration: const InputDecoration(labelText: 'Email (step 1)'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () => _run(() async {
                          await state.forgotPassword(_resetEmail.text.trim());
                          state.setError(
                            state.usesFirebaseAuth
                                ? 'Password reset email sent. Check your inbox.'
                                : 'Reset email sent. Check Mailhog at :8025',
                          );
                        }),
                child: const Text('Send reset email'),
              ),
              const Divider(height: 32),
              TextField(controller: _resetToken, decoration: const InputDecoration(labelText: 'Token from email')),
              TextField(
                controller: _resetPassword,
                decoration: const InputDecoration(labelText: 'New password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () => _run(() async {
                          await state.resetPassword(_resetToken.text.trim(), _resetPassword.text);
                          setState(() => _showReset = false);
                        }),
                child: const Text('Set new password'),
              ),
              TextButton(
                onPressed: () => setState(() => _showReset = false),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Messenger'),
        actions: [
          IconButton(
            tooltip: 'Server settings',
            icon: const Icon(Icons.dns_outlined),
            onPressed: _openServerSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Icon(Icons.chat_bubble_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text('Welcome back', style: Theme.of(context).textTheme.headlineSmall),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: OutlinedButton.icon(
                onPressed: _openServerSettings,
                icon: const Icon(Icons.dns_outlined, size: 18),
                label: Text('Server: ${AppConfig.apiBaseUrl}'),
              ),
            ),
            const SizedBox(height: 8),
            TabBar(
              controller: _tabs,
              tabs: const [Tab(text: 'Login'), Tab(text: 'Register')],
            ),
            if (state.errorMessage != null)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _loginForm(state),
                  _registerForm(state, pwValidation),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loginForm(AppState state) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _loginEmail,
          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPassword,
          decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
          obscureText: true,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loading
              ? null
              : () => _run(() => state.login(_loginEmail.text.trim(), _loginPassword.text)),
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Log in'),
        ),
        TextButton(
          onPressed: () => setState(() => _showReset = true),
          child: const Text('Forgot password?'),
        ),
      ],
    );
  }

  Widget _registerForm(AppState state, PasswordValidation pwValidation) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _regEmail,
          decoration: InputDecoration(
            labelText: 'Email',
            errorText: _emailError,
          ),
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {
            _emailError = null;
          }),
        ),
        TextField(
          controller: _regUsername,
          decoration: InputDecoration(
            labelText: 'Username',
            errorText: _usernameError,
          ),
          onChanged: (_) => setState(() {
            _usernameError = null;
          }),
        ),
        TextField(
          controller: _regPassword,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        ...pwValidation.errors.map(
          (e) => Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: pwValidation.isValid ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(e, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loading || !pwValidation.isValid
              ? null
              : () => _run(() async {
                    setState(() {
                      _emailError = null;
                      _usernameError = null;
                    });
                    final ok = await state.register(
                      _regEmail.text.trim(),
                      _regPassword.text,
                      _regUsername.text.trim(),
                    );
                    if (!ok && mounted) {
                      setState(() {
                        if (state.fieldError == 'email') {
                          _emailError = state.errorMessage;
                        } else if (state.fieldError == 'username') {
                          _usernameError = state.errorMessage;
                        }
                      });
                    }
                    if (ok && mounted) {
                      final sent = state.lastVerificationEmailSent;
                      final usesFirebase = state.usesFirebaseAuth;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            usesFirebase || sent
                                ? 'Account created! Check your inbox (and spam) for the verification email.'
                                : 'Account created! Email was not sent — use Verify now on the next screen.',
                          ),
                          duration: const Duration(seconds: 6),
                        ),
                      );
                    }
                  }),
          child: const Text('Create account'),
        ),
      ],
    );
  }
}
