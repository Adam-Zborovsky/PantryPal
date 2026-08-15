import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/v1',
);

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  final _household = TextEditingController();
  final _invite = TextEditingController();
  bool _registering = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    _household.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final payload = <String, String>{
        'email': _email.text.trim(),
        'password': _password.text,
        'client': 'android',
        if (_registering) ...{
          'displayName': _displayName.text.trim(),
          'householdName': _household.text.trim(),
          'betaInvite': _invite.text.trim(),
          'timezone': DateTime.now().timeZoneName,
        },
      };
      await Dio(
        BaseOptions(
          baseUrl: _apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
        ),
      ).post(_registering ? '/auth/register' : '/auth/login', data: payload);
      if (mounted) ref.read(authenticatedProvider.notifier).state = true;
    } on DioException catch (error) {
      final data = error.response?.data;
      setState(
        () => _error = data is Map && data['message'] is String
            ? data['message'] as String
            : 'Could not connect. Check the API address and try again.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              children: [
                const _CupboardMark(),
                const SizedBox(height: 24),
                Text(
                  _registering ? 'Make room for good meals.' : 'Welcome back.',
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _registering
                      ? 'Your beta invite starts a private household. You can invite others later.'
                      : 'Plan meals together and shop with less guesswork.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_registering) ...[
                            _Field(
                              label: 'Your name',
                              controller: _displayName,
                              textInputAction: TextInputAction.next,
                              validator: _required(
                                'Enter the name your household will see.',
                              ),
                            ),
                            const SizedBox(height: 16),
                            _Field(
                              label: 'Household name',
                              controller: _household,
                              textInputAction: TextInputAction.next,
                              validator: _required(
                                'Give your household a name.',
                              ),
                            ),
                            const SizedBox(height: 16),
                            _Field(
                              label: 'Beta invite',
                              controller: _invite,
                              textInputAction: TextInputAction.next,
                              validator: _required(
                                'Enter your one-time beta invite.',
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _Field(
                            label: 'Email address',
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                value != null &&
                                    RegExp(r'^\S+@\S+\.\S+$').hasMatch(value)
                                ? null
                                : 'Enter a valid email address.',
                          ),
                          const SizedBox(height: 16),
                          _Field(
                            label: 'Password',
                            controller: _password,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            validator: (value) =>
                                value != null && value.length >= 12
                                ? null
                                : 'Use at least 12 characters.',
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: Text(
                              _submitting
                                  ? 'Working…'
                                  : _registering
                                  ? 'Create account'
                                  : 'Sign in',
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _submitting
                                ? null
                                : () => _showJoinHousehold(context),
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Join an existing household'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                          _registering = !_registering;
                          _error = null;
                        }),
                  child: Text(
                    _registering
                        ? 'Already have an account? Sign in'
                        : 'New to PantryPal? Create an account',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your household is private. PantryPal only uses your account to keep plans and shopping in sync.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? Function(String?) _required(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;

  void _showJoinHousehold(BuildContext context) {
    final code = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Join a household',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask a household member for its active invite code. Signing in comes first.',
            ),
            const SizedBox(height: 16),
            _Field(
              label: 'Household invite code',
              controller: code,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Save code for after sign in'),
            ),
          ],
        ),
      ),
    ).whenComplete(code.dispose);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscureText,
        onFieldSubmitted: onSubmitted,
        autocorrect: !obscureText,
        enableSuggestions: !obscureText,
        decoration: InputDecoration(suffixIcon: suffixIcon),
      ),
    ],
  );
}

class _CupboardMark extends StatelessWidget {
  const _CupboardMark();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'PantryPal',
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(color: PantryPalTheme.terracotta, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.kitchen_outlined,
            color: PantryPalTheme.terracotta,
          ),
        ),
        const SizedBox(width: 12),
        Text('PantryPal', style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}
