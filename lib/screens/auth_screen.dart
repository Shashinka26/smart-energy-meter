import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  bool _loading = false;
  bool _ownerExists = false;
  bool _checkingOwner = true;
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
    _loadOwnerStatus();
  }

  Future<void> _loadOwnerStatus() async {
    try {
      final exists = await AuthService.instance.ownerExists();
      if (!mounted) return;
      setState(() {
        _ownerExists = exists;
        _checkingOwner = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ownerExists = false;
        _checkingOwner = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.signIn(
        email: _loginEmailController.text,
        password: _loginPasswordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: _authErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.register(
        email: _registerEmailController.text,
        password: _registerPasswordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: _authErrorMessage(e));
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Registration failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already registered. Try Login instead.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.tint(AppColors.primary, 0.16),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Smart Energy',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to monitor your meter.\nOnly the owner can control the relay.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    onTap: (index) => setState(() => _selectedTab = index),
                    tabs: const [
                      Tab(text: 'Login'),
                      Tab(text: 'Register'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_selectedTab == 0)
                    _buildLoginForm()
                  else if (_checkingOwner)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )
                  else
                    _buildRegisterForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        _textField(
          controller: _loginEmailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _textField(
          controller: _loginPasswordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: _obscureLoginPassword,
          onToggleObscure: () {
            setState(() => _obscureLoginPassword = !_obscureLoginPassword);
          },
        ),
        const SizedBox(height: 24),
        _primaryButton(label: 'Login', onPressed: _loading ? null : _login),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.tint(
              _ownerExists ? AppColors.info : AppColors.primary,
              0.12,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (_ownerExists ? AppColors.info : AppColors.primary)
                  .withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            _ownerExists
                ? 'Owner account exists. New accounts are viewers — you can monitor usage but cannot control the relay.'
                : 'First account on this meter becomes the owner with full relay control.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 14),
        _textField(
          controller: _registerEmailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _textField(
          controller: _registerPasswordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscure: _obscureRegisterPassword,
          onToggleObscure: () {
            setState(
              () => _obscureRegisterPassword = !_obscureRegisterPassword,
            );
          },
        ),
        const SizedBox(height: 24),
        _primaryButton(
          label: 'Create Account',
          onPressed: _loading ? null : _register,
        ),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: onToggleObscure,
              ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
