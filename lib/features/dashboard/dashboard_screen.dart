import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repository.dart';
import 'dashboard_repository.dart';
import 'payment_proof_picker.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositoryProvider);
    final paymentProofPicker = ref.watch(paymentProofPickerProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          TextButton(
            onPressed: () async {
              await authRepository.signOut();
              ref.invalidate(dashboardSummaryProvider);
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
            onRefreshBoarders: () => ref.invalidate(dashboardSummaryProvider),
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
            onCreateDue:
                ({
                  required boarderUserId,
                  required title,
                  required amountCentavos,
                  required dueDate,
                }) async {
                  await ref
                      .read(dashboardRepositoryProvider)
                      .createDue(
                        boarderUserId: boarderUserId,
                        title: title,
                        amountCentavos: amountCentavos,
                        dueDate: dueDate,
                      );
                  ref.invalidate(dashboardSummaryProvider);
                },
            onPickPaymentQr: paymentProofPicker.pickImageProof,
            onSavePaymentSettings:
                ({
                  required paymentLabel,
                  required accountName,
                  required accountNumber,
                  required instructions,
                  qrFile,
                }) async {
                  await ref
                      .read(dashboardRepositoryProvider)
                      .savePaymentSettings(
                        paymentLabel: paymentLabel,
                        accountName: accountName,
                        accountNumber: accountNumber,
                        instructions: instructions,
                        qrFile: qrFile,
                      );
                  ref.invalidate(dashboardSummaryProvider);
                },
            onPickPaymentProof: paymentProofPicker.pickImageProof,
            onSubmitPaymentProof:
                ({
                  required DashboardDue due,
                  required PickedPaymentProofFile file,
                }) async {
                  await ref
                      .read(dashboardRepositoryProvider)
                      .submitPaymentProof(due: due, file: file);
                  ref.invalidate(dashboardSummaryProvider);
                },
            onReviewPaymentProof:
                ({
                  required proofId,
                  required approved,
                  rejectionReason,
                  rejectionNote,
                }) async {
                  await ref
                      .read(dashboardRepositoryProvider)
                      .reviewPaymentProof(
                        proofId: proofId,
                        approved: approved,
                        rejectionReason: rejectionReason,
                        rejectionNote: rejectionNote,
                      );
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
    required this.onCreateDue,
    required this.onRefreshBoarders,
    required this.onPickPaymentQr,
    required this.onSavePaymentSettings,
    required this.onPickPaymentProof,
    required this.onSubmitPaymentProof,
    required this.onReviewPaymentProof,
  });

  final DashboardSummary summary;
  final VoidCallback onRefreshBoarders;
  final Future<void> Function(String name) onCreateOwnerApartment;
  final Future<String> Function() onCreateOwnerInvite;
  final Future<void> Function(String code) onJoinWithInviteCode;
  final Future<void> Function({
    required String boarderUserId,
    required String title,
    required int amountCentavos,
    required DateTime dueDate,
  })
  onCreateDue;
  final Future<PickedPaymentProofFile?> Function() onPickPaymentQr;
  final Future<void> Function({
    required String paymentLabel,
    required String accountName,
    required String accountNumber,
    required String instructions,
    PickedPaymentProofFile? qrFile,
  })
  onSavePaymentSettings;
  final Future<PickedPaymentProofFile?> Function() onPickPaymentProof;
  final Future<void> Function({
    required DashboardDue due,
    required PickedPaymentProofFile file,
  })
  onSubmitPaymentProof;
  final Future<void> Function({
    required String proofId,
    required bool approved,
    String? rejectionReason,
    String? rejectionNote,
  })
  onReviewPaymentProof;

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
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('dashboard-transactions-link'),
                      onPressed: () => context.go('/transactions'),
                      icon: const Icon(Icons.history),
                      label: const Text('View transaction history'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (summary.notifications.isNotEmpty) ...[
                    _NotificationsCard(
                      notifications: summary.notifications,
                      unreadCount: summary.unreadNotificationCount,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (summary.membership == null) ...[
                    _PendingSetupSection(
                      intendedRole: summary.intendedRole,
                      onJoinWithInviteCode: onJoinWithInviteCode,
                      onCreateApartment: onCreateOwnerApartment,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (summary.membership?.isOwner == true) ...[
                    _OwnerInviteCard(onCreateInvite: onCreateOwnerInvite),
                    const SizedBox(height: 24),
                    _OwnerPaymentSettingsCard(
                      paymentSettings: summary.paymentSettings,
                      onPickQrCode: onPickPaymentQr,
                      onSavePaymentSettings: onSavePaymentSettings,
                    ),
                    const SizedBox(height: 24),
                    _OwnerBoardersCard(
                      boarders: summary.boarders,
                      onRefresh: onRefreshBoarders,
                    ),
                    const SizedBox(height: 24),
                    _OwnerPaymentProofsCard(
                      paymentProofs: summary.paymentProofs,
                      onReviewPaymentProof: onReviewPaymentProof,
                    ),
                    const SizedBox(height: 24),
                    _OwnerDuesCard(
                      boarders: summary.boarders,
                      dues: summary.dues,
                      onCreateDue: onCreateDue,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (summary.membership?.isOwner == false) ...[
                    _BoarderPaymentInstructionsCard(
                      paymentSettings: summary.paymentSettings,
                    ),
                    const SizedBox(height: 24),
                    _BoarderDuesCard(
                      dues: summary.dues,
                      onPickPaymentProof: onPickPaymentProof,
                      onSubmitPaymentProof: onSubmitPaymentProof,
                    ),
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

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.notifications,
    required this.unreadCount,
  });

  final List<DashboardNotification> notifications;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (unreadCount > 0)
                  Chip(
                    label: Text('$unreadCount unread'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final (index, notification) in notifications.indexed) ...[
              if (index > 0) const Divider(height: 24),
              _NotificationListItem(notification: notification),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationListItem extends StatelessWidget {
  const _NotificationListItem({required this.notification});

  final DashboardNotification notification;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.primary,
          child: Icon(
            notification.isUnread
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                notification.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(notification.statusLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(notification.createdAtLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingSetupSection extends StatelessWidget {
  const _PendingSetupSection({
    required this.intendedRole,
    required this.onCreateApartment,
    required this.onJoinWithInviteCode,
  });

  final AuthIntendedRole? intendedRole;
  final Future<void> Function(String name) onCreateApartment;
  final Future<void> Function(String code) onJoinWithInviteCode;

  @override
  Widget build(BuildContext context) {
    return switch (intendedRole) {
      AuthIntendedRole.owner => _OwnerOnboardingCard(
        onCreateApartment: onCreateApartment,
      ),
      AuthIntendedRole.boarder => _BoarderJoinCard(
        onJoinWithInviteCode: onJoinWithInviteCode,
      ),
      null => const _MissingRoleCard(),
    };
  }
}

class _MissingRoleCard extends StatelessWidget {
  const _MissingRoleCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              'Account role missing',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'This account was created before owner and boarder signup were separated, so the app cannot safely decide its role. Sign out and create a new owner or boarder account, or update this user metadata in Supabase.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerPaymentSettingsCard extends StatefulWidget {
  const _OwnerPaymentSettingsCard({
    required this.paymentSettings,
    required this.onPickQrCode,
    required this.onSavePaymentSettings,
  });

  final DashboardPaymentSettings? paymentSettings;
  final Future<PickedPaymentProofFile?> Function() onPickQrCode;
  final Future<void> Function({
    required String paymentLabel,
    required String accountName,
    required String accountNumber,
    required String instructions,
    PickedPaymentProofFile? qrFile,
  })
  onSavePaymentSettings;

  @override
  State<_OwnerPaymentSettingsCard> createState() =>
      _OwnerPaymentSettingsCardState();
}

class _OwnerPaymentSettingsCardState extends State<_OwnerPaymentSettingsCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _paymentLabelController;
  late final TextEditingController _accountNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _instructionsController;
  PickedPaymentProofFile? _selectedQrFile;
  String? _errorMessage;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.paymentSettings;
    _paymentLabelController = TextEditingController(
      text: settings?.paymentLabel ?? '',
    );
    _accountNameController = TextEditingController(
      text: settings?.accountName ?? '',
    );
    _accountNumberController = TextEditingController(
      text: settings?.accountNumber ?? '',
    );
    _instructionsController = TextEditingController(
      text: settings?.instructions ?? '',
    );
  }

  @override
  void dispose() {
    _paymentLabelController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickQrCode() async {
    try {
      final file = await widget.onPickQrCode();
      if (file == null) {
        return;
      }

      DashboardRepository.preparePaymentQrImage(
        bytes: file.bytes,
        fileName: file.fileName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedQrFile = file;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    }
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
      await widget.onSavePaymentSettings(
        paymentLabel: _paymentLabelController.text,
        accountName: _accountNameController.text,
        accountNumber: _accountNumberController.text,
        instructions: _instructionsController.text,
        qrFile: _selectedQrFile,
      );

      if (!mounted) {
        return;
      }

      setState(() => _selectedQrFile = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment settings saved.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final existingQrUrl = widget.paymentSettings?.qrSignedUrl;

    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment settings',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell boarders where to pay before they upload receipt proof.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('owner-payment-label-field'),
                controller: _paymentLabelController,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  hintText: 'Example: GCash',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the payment method.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('owner-payment-account-name-field'),
                controller: _accountNameController,
                decoration: const InputDecoration(
                  labelText: 'Account name',
                  hintText: 'Example: Apari Owner',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the account name.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('owner-payment-account-number-field'),
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Account number',
                  hintText: 'Example: 09170000000',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the account number.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('owner-payment-instructions-field'),
                controller: _instructionsController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'Example: Send exact amount, then upload receipt.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('owner-payment-qr-pick-button'),
                    onPressed: _isSubmitting ? null : _pickQrCode,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Choose QR image'),
                  ),
                  if (_selectedQrFile != null)
                    Text(
                      _selectedQrFile!.fileName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    )
                  else if (existingQrUrl != null)
                    Text(
                      'Current QR code saved',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                ],
              ),
              if (existingQrUrl != null && _selectedQrFile == null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    existingQrUrl,
                    key: const Key('owner-payment-current-qr-image'),
                    height: 160,
                    width: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, _) => Container(
                      height: 120,
                      width: 160,
                      alignment: Alignment.center,
                      color: colorScheme.surface,
                      child: Text(
                        'Could not preview QR.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
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
                  key: const Key('owner-payment-settings-submit-button'),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save payment settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoarderPaymentInstructionsCard extends StatelessWidget {
  const _BoarderPaymentInstructionsCard({required this.paymentSettings});

  final DashboardPaymentSettings? paymentSettings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = paymentSettings;

    return Card(
      elevation: 0,
      color: colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to pay',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (settings == null)
              Text(
                'No payment instructions yet. Ask the owner before sending payment.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
              )
            else ...[
              Text(
                'Pay outside the app first, then upload your receipt proof.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PaymentDetailChip(
                    label: 'Method',
                    value: settings.paymentLabel,
                  ),
                  _PaymentDetailChip(
                    label: 'Account name',
                    value: settings.accountName,
                  ),
                  _PaymentDetailChip(
                    label: 'Account number',
                    value: settings.accountNumber,
                  ),
                ],
              ),
              if (settings.hasInstructions) ...[
                const SizedBox(height: 16),
                Text(
                  settings.instructions!.trim(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
              if (settings.qrSignedUrl != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    settings.qrSignedUrl!,
                    key: const Key('boarder-payment-qr-image'),
                    height: 220,
                    width: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, _) => Container(
                      height: 140,
                      width: 220,
                      alignment: Alignment.center,
                      color: colorScheme.surface,
                      child: Text(
                        'Could not preview payment QR.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentDetailChip extends StatelessWidget {
  const _PaymentDetailChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerPaymentProofsCard extends StatefulWidget {
  const _OwnerPaymentProofsCard({
    required this.paymentProofs,
    required this.onReviewPaymentProof,
  });

  final List<DashboardPaymentProof> paymentProofs;
  final Future<void> Function({
    required String proofId,
    required bool approved,
    String? rejectionReason,
    String? rejectionNote,
  })
  onReviewPaymentProof;

  @override
  State<_OwnerPaymentProofsCard> createState() =>
      _OwnerPaymentProofsCardState();
}

class _OwnerPaymentProofsCardState extends State<_OwnerPaymentProofsCard> {
  String? _reviewingProofId;
  String? _errorMessage;

  Future<void> _review(
    DashboardPaymentProof proof, {
    required bool approved,
    String? rejectionReason,
    String? rejectionNote,
  }) async {
    if (_reviewingProofId != null) {
      return;
    }

    setState(() {
      _reviewingProofId = proof.id;
      _errorMessage = null;
    });

    try {
      await widget.onReviewPaymentProof(
        proofId: proof.id,
        approved: approved,
        rejectionReason: rejectionReason,
        rejectionNote: rejectionNote,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? 'Payment proof approved.' : 'Payment proof rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _reviewingProofId = null);
      }
    }
  }

  Future<void> _reject(DashboardPaymentProof proof) async {
    final rejection = await _showPaymentProofRejectionDialog(context);
    if (rejection == null) {
      return;
    }

    await _review(
      proof,
      approved: false,
      rejectionReason: rejection.reason.code,
      rejectionNote: rejection.note,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pendingCount = widget.paymentProofs
        .where((proof) => proof.isPending)
        .length;

    return Card(
      elevation: 0,
      color: colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment proofs',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              pendingCount == 0
                  ? 'No pending payment proofs to review.'
                  : '$pendingCount proof${pendingCount == 1 ? '' : 's'} waiting for review.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
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
            if (widget.paymentProofs.isEmpty)
              Text(
                'Boarders can upload a compressed receipt image after you assign a due.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
              )
            else
              Column(
                children: [
                  for (final proof in widget.paymentProofs) ...[
                    _PaymentProofListTile(
                      proof: proof,
                      isReviewing: _reviewingProofId == proof.id,
                      onApprove: () => _review(proof, approved: true),
                      onReject: () => _reject(proof),
                    ),
                    if (proof != widget.paymentProofs.last)
                      const Divider(height: 28),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentProofListTile extends StatelessWidget {
  const _PaymentProofListTile({
    required this.proof,
    required this.isReviewing,
    required this.onApprove,
    required this.onReject,
  });

  final DashboardPaymentProof proof;
  final bool isReviewing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.primary,
              child: const Icon(Icons.fact_check_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proof.boarderName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    proof.dueTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DueBadge(label: proof.amountLabel),
                      _DueBadge(label: 'Sent ${proof.submittedAtLabel}'),
                      _DueBadge(label: proof.statusLabel),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (proof.signedUrl != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              proof.signedUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => Container(
                height: 120,
                alignment: Alignment.center,
                color: colorScheme.surface,
                child: Text(
                  'Could not preview this proof image.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: Key('owner-proof-preview-${proof.id}'),
            onPressed: () => _showPaymentProofPreviewDialog(context, proof),
            icon: const Icon(Icons.open_in_full),
            label: const Text('View full screen'),
          ),
        ],
        if (proof.isPending) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: Key('owner-proof-approve-${proof.id}'),
                onPressed: isReviewing ? null : onApprove,
                icon: isReviewing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Approve'),
              ),
              OutlinedButton.icon(
                key: Key('owner-proof-reject-${proof.id}'),
                onPressed: isReviewing ? null : onReject,
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PaymentProofRejection {
  const _PaymentProofRejection({required this.reason, required this.note});

  final PaymentProofRejectionReason reason;
  final String? note;
}

Future<_PaymentProofRejection?> _showPaymentProofRejectionDialog(
  BuildContext context,
) {
  return showDialog<_PaymentProofRejection>(
    context: context,
    builder: (context) => const _PaymentProofRejectionDialog(),
  );
}

class _PaymentProofRejectionDialog extends StatefulWidget {
  const _PaymentProofRejectionDialog();

  @override
  State<_PaymentProofRejectionDialog> createState() =>
      _PaymentProofRejectionDialogState();
}

class _PaymentProofRejectionDialogState
    extends State<_PaymentProofRejectionDialog> {
  final _noteController = TextEditingController();
  var _selectedReason = PaymentProofRejectionReason.invalidReceipt;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      _PaymentProofRejection(
        reason: _selectedReason,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject payment proof'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<PaymentProofRejectionReason>(
            key: const Key('proof-rejection-reason-field'),
            initialValue: _selectedReason,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final reason in PaymentProofRejectionReason.values)
                DropdownMenuItem(value: reason, child: Text(reason.label)),
            ],
            onChanged: (reason) {
              if (reason == null) {
                return;
              }

              setState(() => _selectedReason = reason);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('proof-rejection-note-field'),
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Optional note',
              hintText: 'Example: Receipt date does not match.',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('proof-rejection-submit-button'),
          onPressed: _submit,
          child: const Text('Reject proof'),
        ),
      ],
    );
  }
}

Future<void> _showPaymentProofPreviewDialog(
  BuildContext context,
  DashboardPaymentProof proof,
) {
  final signedUrl = proof.signedUrl;
  if (signedUrl == null) {
    return Future.value();
  }

  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Payment proof preview'),
            actions: [
              TextButton(
                key: const Key('proof-preview-close-button'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                signedUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, _, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Could not preview this proof image.'),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _OwnerDuesCard extends StatefulWidget {
  const _OwnerDuesCard({
    required this.boarders,
    required this.dues,
    required this.onCreateDue,
  });

  final List<DashboardBoarder> boarders;
  final List<DashboardDue> dues;
  final Future<void> Function({
    required String boarderUserId,
    required String title,
    required int amountCentavos,
    required DateTime dueDate,
  })
  onCreateDue;

  @override
  State<_OwnerDuesCard> createState() => _OwnerDuesCardState();
}

class _OwnerDuesCardState extends State<_OwnerDuesCard> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _dueDateController = TextEditingController();
  String? _selectedBoarderUserId;
  String? _errorMessage;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedBoarderUserId = widget.boarders.firstOrNull?.userId;
  }

  @override
  void didUpdateWidget(covariant _OwnerDuesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedUserStillExists = widget.boarders.any(
      (boarder) => boarder.userId == _selectedBoarderUserId,
    );
    if (!selectedUserStillExists) {
      _selectedBoarderUserId = widget.boarders.firstOrNull?.userId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    final boarderUserId = _selectedBoarderUserId;
    final amountCentavos = _parsePesoAmountToCentavos(_amountController.text);
    final dueDate = _parseDueDate(_dueDateController.text);

    if (!isValid ||
        _isSubmitting ||
        boarderUserId == null ||
        amountCentavos == null ||
        dueDate == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onCreateDue(
        boarderUserId: boarderUserId,
        title: _titleController.text,
        amountCentavos: amountCentavos,
        dueDate: dueDate,
      );

      if (!mounted) {
        return;
      }

      _titleController.clear();
      _amountController.clear();
      _dueDateController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Due created.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create due',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Assign rent, utilities, or other dues to a boarder.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            if (widget.boarders.isEmpty)
              Text(
                'Invite a boarder before creating dues.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      key: const Key('owner-due-boarder-field'),
                      initialValue: _selectedBoarderUserId,
                      decoration: const InputDecoration(
                        labelText: 'Boarder',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final boarder in widget.boarders)
                          DropdownMenuItem(
                            value: boarder.userId,
                            child: Text(boarder.displayName),
                          ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) =>
                                setState(() => _selectedBoarderUserId = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('owner-due-title-field'),
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Due title',
                        hintText: 'Example: July rent',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a due title.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('owner-due-amount-field'),
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Example: 1500',
                        prefixText: 'P ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (_parsePesoAmountToCentavos(value ?? '') == null) {
                          return 'Enter a valid peso amount.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('owner-due-date-field'),
                      controller: _dueDateController,
                      decoration: const InputDecoration(
                        labelText: 'Due date',
                        hintText: 'YYYY-MM-DD',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (_parseDueDate(value ?? '') == null) {
                          return 'Enter a valid date like 2026-07-31.';
                        }

                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        key: const Key('owner-due-submit-button'),
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save due'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _DueList(
              dues: widget.dues,
              emptyMessage: 'No dues have been created yet.',
              showBoarderName: true,
            ),
          ],
        ),
      ),
    );
  }
}

enum _BoarderProofPreviewAction { chooseAnother, submit }

Future<_BoarderProofPreviewAction?> _showBoarderProofPreviewDialog({
  required BuildContext context,
  required String fileName,
  required PreparedPaymentProofImage preparedImage,
}) {
  return showDialog<_BoarderProofPreviewAction>(
    context: context,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;

      return AlertDialog(
        title: const Text('Review payment proof'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'This preview is compressed to JPG before upload to keep storage small.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  preparedImage.bytes,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('proof-preview-choose-another-button'),
            onPressed: () => Navigator.of(
              context,
            ).pop(_BoarderProofPreviewAction.chooseAnother),
            child: const Text('Choose another'),
          ),
          FilledButton(
            key: const Key('proof-preview-submit-button'),
            onPressed: () =>
                Navigator.of(context).pop(_BoarderProofPreviewAction.submit),
            child: const Text('Submit proof'),
          ),
        ],
      );
    },
  );
}

class _BoarderDuesCard extends StatefulWidget {
  const _BoarderDuesCard({
    required this.dues,
    required this.onPickPaymentProof,
    required this.onSubmitPaymentProof,
  });

  final List<DashboardDue> dues;
  final Future<PickedPaymentProofFile?> Function() onPickPaymentProof;
  final Future<void> Function({
    required DashboardDue due,
    required PickedPaymentProofFile file,
  })
  onSubmitPaymentProof;

  @override
  State<_BoarderDuesCard> createState() => _BoarderDuesCardState();
}

class _BoarderDuesCardState extends State<_BoarderDuesCard> {
  String? _submittingDueId;
  String? _errorMessage;

  Future<void> _submitPaymentProof(DashboardDue due) async {
    if (_submittingDueId != null) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      while (mounted) {
        final file = await widget.onPickPaymentProof();
        if (file == null) {
          return;
        }

        final preparedImage = DashboardRepository.preparePaymentProofImage(
          bytes: file.bytes,
          fileName: file.fileName,
        );
        if (!mounted) {
          return;
        }

        final action = await _showBoarderProofPreviewDialog(
          context: context,
          fileName: file.fileName,
          preparedImage: preparedImage,
        );

        if (action == _BoarderProofPreviewAction.chooseAnother) {
          continue;
        }

        if (action != _BoarderProofPreviewAction.submit) {
          return;
        }

        setState(() => _submittingDueId = due.id);
        await widget.onSubmitPaymentProof(due: due, file: file);

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment proof submitted.')),
        );
        return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _submittingDueId = null);
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
              'My dues',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'These are the dues assigned to your account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            _DueList(
              dues: widget.dues,
              emptyMessage: 'No dues assigned yet.',
              showBoarderName: false,
              onSubmitPaymentProof: _submitPaymentProof,
              submittingDueId: _submittingDueId,
            ),
          ],
        ),
      ),
    );
  }
}

class _DueList extends StatelessWidget {
  const _DueList({
    required this.dues,
    required this.emptyMessage,
    required this.showBoarderName,
    this.onSubmitPaymentProof,
    this.submittingDueId,
  });

  final List<DashboardDue> dues;
  final String emptyMessage;
  final bool showBoarderName;
  final Future<void> Function(DashboardDue due)? onSubmitPaymentProof;
  final String? submittingDueId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (dues.isEmpty) {
      return Text(
        emptyMessage,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      );
    }

    return Column(
      children: [
        for (final due in dues) ...[
          _DueListTile(
            due: due,
            showBoarderName: showBoarderName,
            onSubmitPaymentProof: onSubmitPaymentProof,
            isSubmittingProof: submittingDueId == due.id,
          ),
          if (due != dues.last) const Divider(height: 24),
        ],
      ],
    );
  }
}

class _DueListTile extends StatelessWidget {
  const _DueListTile({
    required this.due,
    required this.showBoarderName,
    this.onSubmitPaymentProof,
    this.isSubmittingProof = false,
  });

  final DashboardDue due;
  final bool showBoarderName;
  final Future<void> Function(DashboardDue due)? onSubmitPaymentProof;
  final bool isSubmittingProof;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.primary,
          child: const Icon(Icons.receipt_long_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                due.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (showBoarderName) ...[
                const SizedBox(height: 2),
                Text(
                  due.boarderName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DueBadge(label: due.amountLabel),
                  _DueBadge(label: 'Due ${due.dueDateLabel}'),
                  _DueBadge(label: due.statusLabel),
                ],
              ),
              if (onSubmitPaymentProof != null && due.canSubmitProof) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: Key('boarder-proof-upload-${due.id}'),
                  onPressed: isSubmittingProof
                      ? null
                      : () => onSubmitPaymentProof!(due),
                  icon: isSubmittingProof
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(isSubmittingProof ? 'Uploading' : 'Upload proof'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
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

class _OwnerBoardersCard extends StatelessWidget {
  const _OwnerBoardersCard({required this.boarders, required this.onRefresh});

  final List<DashboardBoarder> boarders;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = boarders.length;
    final countLabel = count == 1
        ? '1 boarder in this apartment'
        : '$count boarders in this apartment';

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Boarders',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('owner-boarders-refresh-button'),
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh boarders'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              count == 0
                  ? 'No boarders have joined this apartment yet.'
                  : countLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (boarders.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Create an invite code and send it to a boarder before assigning dues.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              for (final boarder in boarders) ...[
                _BoarderListTile(boarder: boarder),
                if (boarder != boarders.last) const Divider(height: 24),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _BoarderListTile extends StatelessWidget {
  const _BoarderListTile({required this.boarder});

  final DashboardBoarder boarder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: const Icon(Icons.person_outline),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                boarder.displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                boarder.phoneLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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

int? _parsePesoAmountToCentavos(String value) {
  final cleanedValue = value.trim().replaceAll(',', '');
  final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(cleanedValue);
  if (match == null) {
    return null;
  }

  final parts = cleanedValue.split('.');
  final pesos = int.tryParse(parts.first);
  if (pesos == null) {
    return null;
  }

  final centavos = parts.length == 2
      ? int.tryParse(parts.last.padRight(2, '0'))
      : 0;
  if (centavos == null) {
    return null;
  }

  final amountCentavos = (pesos * 100) + centavos;
  return amountCentavos > 0 ? amountCentavos : null;
}

DateTime? _parseDueDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (match == null) {
    return null;
  }

  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) {
    return null;
  }

  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }

  return date;
}
