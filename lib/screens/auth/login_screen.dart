import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../constants/app_constants.dart';
import '../../widgets/aves_logo_widget.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadLastUsername();
  }

  @override
  void dispose() {
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('last_username') ?? '';
    if (!mounted || last.isEmpty) {
      return;
    }
    setState(() => _usernameCtrl.text = last);
  }

  Future<void> _saveLastUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_username', username);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final auth = ref.read(authProvider);
    final username = _usernameCtrl.text.trim();
    final ok = await auth.signIn(username, _passCtrl.text);
    if (!mounted) {
      return;
    }
    if (ok) {
      await _saveLastUsername(username);
      _navigateToDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Errore di accesso'),
          backgroundColor: AppColors.currencyExpired,
        ),
      );
    }
  }

  void _navigateToDashboard() {
    final auth = ref.read(authProvider);
    if (auth.isAdminPriv) {
      context.go('/admin/priv');
    } else if (auth.isAdminCrew) {
      context.go('/admin/crew');
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final logoSize = isMobile ? 96.0 : 120.0;
    final cardPadding = isMobile ? 20.0 : 28.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryDark,
              AppColors.background,
              AppColors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AvesLogoWidget(size: logoSize),
                    const SizedBox(height: 24),
                    Text(
                      'AVES',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            letterSpacing: 10,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'AVIAZIONE DELL\'ESERCITO',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.secondary,
                        letterSpacing: 2.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gestione Currency',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'ACCESSO',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(letterSpacing: 1.8),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Accedi al tuo profilo operativo.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _usernameCtrl,
                                focusNode: _usernameFocus,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Numero Licenza / Username',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Campo obbligatorio'
                                    : null,
                                onFieldSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_passwordFocus),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passCtrl,
                                focusNode: _passwordFocus,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                obscureText: _obscure,
                                validator: (value) =>
                                    value == null || value.length < 4
                                    ? 'Password troppo corta'
                                    : null,
                                onFieldSubmitted: (_) => _login(),
                              ),
                              const SizedBox(height: 24),
                              if (auth.isLoading)
                                const Center(child: CircularProgressIndicator())
                              else
                                ElevatedButton(
                                  onPressed: _login,
                                  child: const Text('ACCEDI'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Non hai un account? Registrati'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
