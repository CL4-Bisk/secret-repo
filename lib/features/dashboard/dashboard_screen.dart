import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repository.dart';
import 'dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositoryProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          TextButton(
            onPressed: () async {
              await authRepository.signOut();
              if (context.mounted) {
                context.go('/');
              }
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: summary.when(
          data: (value) => _DashboardContent(
            summary: value,
            onCreateOwnerApartment: (name) async {
              await ref
                  .read(dashboardRepositoryProvider)
                  .createOwnerApartment(name: name);
              ref.invalidate(dashboardSummaryProvider);
            },
            onCreateOwnerInvite: () {
              return ref.read(dashboardRepositoryProvider).createOwnerInvite();
            },
            onJoinWithInviteCode: (code) async {
              await ref
                  .read(dashboardRepositoryProvider)
                  .joinWithInviteCode(code: code);
              ref.invalidate(dashboardSummaryProvider);
            },
          ),
          error: (error, _) => _DashboardError(
            message: error.toString(),
            colorScheme: colorScheme,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.summary,
    required this.onCreateOwnerApartment,
    required this.onCreateOwnerInvite,
    required this.onJoinWithInviteCode,
  });

  final DashboardSummary summary;
  final Future<void> Function(String name) onCreateOwnerApartment;
  final Future<String> Function() onCreateOwnerInvite;
  final Future<void> Function(String code) onJoinWithInviteCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dashboard',
                    key: const Key('dashboard-screen-title'),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary.primaryIdentityLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (summary.membership == null) ...[
                    _BoarderJoinCard(
                      onJoinWithInviteCode: onJoinWithInviteCode,
                    ),
                    const SizedBox(height: 24),
                    _OwnerSetupToggle(
                      onCreateApartment: onCreateOwnerApartment,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (summary.membership?.isOwner == true) ...[
                    _OwnerInviteCard(onCreateInvite: onCreateOwnerInvite),
                    const SizedBox(height: 24),
                  ],
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _DashboardSummaryCard(
                        title: 'Role',
                        value: summary.roleLabel,
                        description: summary.roleDescription,
                      ),
                      _DashboardSummaryCard(
                        title: 'Apartment',
                        value: summary.apartmentLabel,
                        description: summary.apartmentDescription,
                      ),
                      const _DashboardSummaryCard(
                        title: 'Payments',
                        value: 'Manual proof first',
                        description:
                            'Dues and proof uploads come after onboarding.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OwnerInviteCard extends StatefulWidget {
  const _OwnerInviteCard({required this.onCreateInvite});

  final Future<String> Function() onCreateInvite;

  @override
  State<_OwnerInviteCard> createState() => _OwnerInviteCardState();
}

class _OwnerInviteCardState extends State<_OwnerInviteCard> {
  var _isSubmitting = false;
  String? _inviteCode;
  String? _errorMessage;

  Future<void> _createInvite() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final inviteCode = await widget.onCreateInvite();
      if (!mounted) {
        return;
      }

      setState(() {
        _inviteCode = inviteCode;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite boarders',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a code, send it to a boarder, and they can join this apartment from their dashboard.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            if (_inviteCode != null) ...[
              const SizedBox(height: 16),
              SelectableText(
                _inviteCode!,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('owner-invite-create-button'),
                onPressed: _isSubmitting ? null : _createInvite,
                child: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create invite code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerSetupToggle extends StatefulWidget {
  const _OwnerSetupToggle({required this.onCreateApartment});

  final Future<void> Function(String name) onCreateApartment;

  @override
  State<_OwnerSetupToggle> createState() => _OwnerSetupToggleState();
}

class _OwnerSetupToggleState extends State<_OwnerSetupToggle> {
  var _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isExpanded) {
      return _OwnerOnboardingCard(onCreateApartment: widget.onCreateApartment);
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Owner setup',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Only use this if you manage the apartment. Boarders should join with an invite code above.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                key: const Key('owner-setup-show-button'),
                onPressed: () => setState(() => _isExpanded = true),
                child: const Text('Show owner setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerOnboardingCard extends StatefulWidget {
  const _OwnerOnboardingCard({required this.onCreateApartment});

  final Future<void> Function(String name) onCreateApartment;

  @override
  State<_OwnerOnboardingCard> createState() => _OwnerOnboardingCardState();
}

class _OwnerOnboardingCardState extends State<_OwnerOnboardingCard> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  var _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onCreateApartment(_nameController.text);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Apartment created.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create your apartment',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This makes you the owner and unlocks dues setup for boarders.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('owner-onboarding-apartment-name-field'),
                controller: _nameController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Apartment name',
                  hintText: 'Example: My Apartment',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the apartment name.';
                  }

                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('owner-onboarding-submit-button'),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create apartment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoarderJoinCard extends StatefulWidget {
  const _BoarderJoinCard({required this.onJoinWithInviteCode});

  final Future<void> Function(String code) onJoinWithInviteCode;

  @override
  State<_BoarderJoinCard> createState() => _BoarderJoinCardState();
}

class _BoarderJoinCardState extends State<_BoarderJoinCard> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  var _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onJoinWithInviteCode(_codeController.text);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Apartment joined.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join an apartment',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the invite code from your owner to join as a boarder.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('boarder-join-invite-code-field'),
                controller: _codeController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  hintText: 'Example: CL4B-9X2A',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) {
                  final normalizedCode =
                      DashboardRepository.normalizeInviteCode(value ?? '');
                  if (normalizedCode.length != 9) {
                    return 'Enter the full invite code.';
                  }

                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('boarder-join-submit-button'),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Join apartment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.colorScheme});

  final String message;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 0,
            color: colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dashboard data failed to load',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSummaryCard extends StatelessWidget {
  const _DashboardSummaryCard({
    required this.title,
    required this.value,
    required this.description,
  });

  final String title;
  final String value;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 296,
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
