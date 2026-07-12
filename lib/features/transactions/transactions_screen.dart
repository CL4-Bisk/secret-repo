import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../dashboard/dashboard_repository.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(transactionHistoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          TextButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Dashboard'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(transactionHistoryProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: history.when(
          data: (value) => _TransactionHistoryContent(history: value),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  elevation: 0,
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Transaction history failed to load\n$error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ),
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _TransactionHistoryContent extends StatefulWidget {
  const _TransactionHistoryContent({required this.history});

  final TransactionHistory history;

  @override
  State<_TransactionHistoryContent> createState() =>
      _TransactionHistoryContentState();
}

class _TransactionHistoryContentState
    extends State<_TransactionHistoryContent> {
  var _dueStatusFilter = 'all';
  var _proofStatusFilter = 'all';
  String? _boarderUserIdFilter;

  @override
  void didUpdateWidget(covariant _TransactionHistoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    final selectedBoarderStillExists = widget.history.boarders.any(
      (boarder) => boarder.userId == _boarderUserIdFilter,
    );
    if (_boarderUserIdFilter != null && !selectedBoarderStillExists) {
      _boarderUserIdFilter = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredDues = _filteredDues();
    final filteredProofs = _filteredProofs();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Transaction history',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Filter dues and payment proof attempts without crowding the dashboard. <temp header>',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _HistoryFilters(
                history: widget.history,
                dueStatusFilter: _dueStatusFilter,
                proofStatusFilter: _proofStatusFilter,
                boarderUserIdFilter: _boarderUserIdFilter,
                onDueStatusChanged: (status) {
                  setState(() => _dueStatusFilter = status);
                },
                onProofStatusChanged: (status) {
                  setState(() => _proofStatusFilter = status);
                },
                onBoarderChanged: (boarderUserId) {
                  setState(() => _boarderUserIdFilter = boarderUserId);
                },
              ),
              const SizedBox(height: 24),
              _HistorySection(
                title: 'Dues',
                emptyMessage: 'No dues match these filters.',
                children: [
                  for (final due in filteredDues) _HistoryDueTile(due: due),
                ],
              ),
              const SizedBox(height: 24),
              _HistorySection(
                title: 'Payment proofs',
                emptyMessage: 'No payment proofs match these filters.',
                children: [
                  for (final proof in filteredProofs)
                    _HistoryProofTile(proof: proof),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DashboardDue> _filteredDues() {
    final dues = widget.history.dues.where((due) {
      return _matchesBoarder(due.boarderUserId) &&
          _matchesStatus(due.status, _dueStatusFilter);
    }).toList();

    dues.sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return dues;
  }

  List<DashboardPaymentProof> _filteredProofs() {
    final proofs = widget.history.paymentProofs.where((proof) {
      return _matchesBoarder(proof.boarderUserId) &&
          _matchesStatus(proof.status, _proofStatusFilter);
    }).toList();

    proofs.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return proofs;
  }

  bool _matchesBoarder(String boarderUserId) {
    final selectedBoarderUserId = _boarderUserIdFilter;
    return selectedBoarderUserId == null ||
        selectedBoarderUserId == boarderUserId;
  }

  static bool _matchesStatus(String value, String filter) {
    return filter == 'all' || value.toLowerCase() == filter;
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.history,
    required this.dueStatusFilter,
    required this.proofStatusFilter,
    required this.boarderUserIdFilter,
    required this.onDueStatusChanged,
    required this.onProofStatusChanged,
    required this.onBoarderChanged,
  });

  final TransactionHistory history;
  final String dueStatusFilter;
  final String proofStatusFilter;
  final String? boarderUserIdFilter;
  final ValueChanged<String> onDueStatusChanged;
  final ValueChanged<String> onProofStatusChanged;
  final ValueChanged<String?> onBoarderChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _FilterGroup(
              label: 'Due status',
              children: [
                _FilterChipOption(
                  keyValue: 'history-due-status-filter-all',
                  label: 'All dues',
                  selected: dueStatusFilter == 'all',
                  onSelected: () => onDueStatusChanged('all'),
                ),
                for (final status in _dueStatuses)
                  _FilterChipOption(
                    keyValue: 'history-due-status-filter-$status',
                    label: _dueStatusLabel(status),
                    selected: dueStatusFilter == status,
                    onSelected: () => onDueStatusChanged(status),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _FilterGroup(
              label: 'Proof status',
              children: [
                _FilterChipOption(
                  keyValue: 'history-proof-status-filter-all',
                  label: 'All proofs',
                  selected: proofStatusFilter == 'all',
                  onSelected: () => onProofStatusChanged('all'),
                ),
                for (final status in _proofStatuses)
                  _FilterChipOption(
                    keyValue: 'history-proof-status-filter-$status',
                    label: _proofStatusLabel(status),
                    selected: proofStatusFilter == status,
                    onSelected: () => onProofStatusChanged(status),
                  ),
              ],
            ),
            if (history.isOwner && history.boarders.isNotEmpty) ...[
              const SizedBox(height: 16),
              _FilterGroup(
                label: 'Boarder',
                children: [
                  _FilterChipOption(
                    keyValue: 'history-boarder-filter-all',
                    label: 'All boarders',
                    selected: boarderUserIdFilter == null,
                    onSelected: () => onBoarderChanged(null),
                  ),
                  for (final boarder in history.boarders)
                    _FilterChipOption(
                      keyValue: 'history-boarder-filter-${boarder.userId}',
                      label: boarder.displayName,
                      selected: boarderUserIdFilter == boarder.userId,
                      onSelected: () => onBoarderChanged(boarder.userId),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _FilterChipOption extends StatelessWidget {
  const _FilterChipOption({
    required this.keyValue,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String keyValue;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      key: Key(keyValue),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> children;

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
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (children.isEmpty)
              Text(
                emptyMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              )
            else
              Column(
                children: [
                  for (final child in children) ...[
                    child,
                    if (child != children.last) const Divider(height: 28),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDueTile extends StatelessWidget {
  const _HistoryDueTile({required this.due});

  final DashboardDue due;

  @override
  Widget build(BuildContext context) {
    return _HistoryTile(
      icon: Icons.receipt_long_outlined,
      title: due.title,
      subtitle: due.boarderName,
      badges: [
        due.amountLabel,
        'Due ${due.dueDateLabel}',
        due.statusLabel,
      ],
    );
  }
}

class _HistoryProofTile extends StatelessWidget {
  const _HistoryProofTile({required this.proof});

  final DashboardPaymentProof proof;

  @override
  Widget build(BuildContext context) {
    return _HistoryTile(
      icon: Icons.fact_check_outlined,
      title: proof.dueTitle,
      subtitle: proof.boarderName,
      badges: [
        proof.amountLabel,
        'Sent ${proof.submittedAtLabel}',
        proof.statusLabel,
        if (proof.status.toLowerCase() == 'rejected')
          proof.rejectionReasonLabel,
      ],
      detail: proof.rejectionNote,
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badges,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> badges;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.primary,
          child: Icon(icon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final badge in badges) _HistoryBadge(label: badge),
                ],
              ),
              if (detail?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  detail!.trim(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryBadge extends StatelessWidget {
  const _HistoryBadge({required this.label});

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

const _dueStatuses = ['unpaid', 'proof_submitted', 'paid', 'rejected'];
const _proofStatuses = ['pending', 'approved', 'rejected'];

String _dueStatusLabel(String status) {
  return switch (status) {
    'unpaid' => 'Unpaid',
    'proof_submitted' => 'Proof submitted',
    'paid' => 'Paid',
    'rejected' => 'Rejected',
    _ => status,
  };
}

String _proofStatusLabel(String status) {
  return switch (status) {
    'pending' => 'Pending',
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    _ => status,
  };
}
