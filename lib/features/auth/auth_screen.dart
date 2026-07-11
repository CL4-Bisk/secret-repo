import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../dashboard/dashboard_repository.dart';
import 'auth_repository.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScaffold(
      title: 'Sign in',
      subtitle: 'Access your apartment dashboard.',
      submitLabel: 'Sign in',
      mode: AuthFormMode.signIn,
    );
  }
}

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({required this.intendedRole, super.key});

  final AuthIntendedRole intendedRole;

  @override
  Widget build(BuildContext context) {
    final isOwner = intendedRole == AuthIntendedRole.owner;

    return AuthScaffold(
      title: isOwner ? 'Create owner account' : 'Create boarder account',
      subtitle: isOwner
          ? 'Create your login first, then create the apartment record.'
          : 'Create your login first, then join with the owner invite code.',
      submitLabel: 'Create account',
      mode: AuthFormMode.signUp,
      intendedRole: intendedRole,
    );
  }
}

enum AuthFormMode { signIn, signUp }

class AuthScaffold extends ConsumerStatefulWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.submitLabel,
    required this.mode,
    this.intendedRole,
    super.key,
  });

  final String title;
  final String subtitle;
  final String submitLabel;
  final AuthFormMode mode;
  final AuthIntendedRole? intendedRole;

  @override
  ConsumerState<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends ConsumerState<AuthScaffold> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSubmitting = false;

  bool get _isSignUp => widget.mode == AuthFormMode.signUp;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(authRepositoryProvider);

      if (_isSignUp) {
        final intendedRole = widget.intendedRole;
        if (intendedRole == null) {
          throw StateError('Choose owner or boarder signup first.');
        }

        await repository.signUp(
          fullName: _fullNameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          intendedRole: intendedRole,
        );
      } else {
        await repository.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) {
        return;
      }

      ref.invalidate(dashboardSummaryProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSignUp ? 'Account created. Check your email.' : 'Signed in.',
          ),
        ),
      );

      if (!_isSignUp) {
        context.go('/dashboard');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          key: const Key('auth-screen-title'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),
                        if (_isSignUp) ...[
                          TextFormField(
                            key: const Key('auth-full-name-field'),
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              border: OutlineInputBorder(),
                            ),
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          key: const Key('auth-email-field'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: _emailValidator,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('auth-password-field'),
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          validator: _passwordValidator,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('auth-submit-button'),
                          onPressed: _isSubmitting ? null : _submit,
                          child: Text(
                            _isSubmitting
                                ? 'Please wait...'
                                : widget.submitLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }

  return null;
}

String? _emailValidator(String? value) {
  final trimmedValue = value?.trim() ?? '';
  if (trimmedValue.isEmpty) {
    return 'Email is required';
  }

  if (!trimmedValue.contains('@')) {
    return 'Enter a valid email';
  }

  return null;
}

String? _passwordValidator(String? value) {
  if (value == null || value.length < 6) {
    return 'Password must be at least 6 characters';
  }

  return null;
}
