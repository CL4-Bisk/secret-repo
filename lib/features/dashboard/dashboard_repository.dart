import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    client: ref.watch(supabaseClientProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) {
  return ref.watch(dashboardRepositoryProvider).fetchSummary();
});

class DashboardRepository {
  static const membershipUserIdColumn = 'user_id';

  const DashboardRepository({
    required this.client,
    required this.authRepository,
  });

  final SupabaseClient client;
  final AuthRepository authRepository;

  Future<DashboardSummary> fetchSummary() async {
    final userId = authRepository.currentUserId;
    final email = authRepository.currentUserEmail ?? 'Signed in user';

    if (userId == null) {
      return DashboardSummary(displayName: email, email: email);
    }

    final profile = await client
        .from('profiles')
        .select('id, full_name')
        .eq('id', userId)
        .maybeSingle();

    final membership = await client
        .from('memberships')
        .select('role, organization_id, organizations(id, name)')
        .eq(membershipUserIdColumn, userId)
        .limit(1)
        .maybeSingle();

    return DashboardSummary(
      displayName: _readString(profile, 'full_name') ?? email,
      email: email,
      membership: _membershipFromRow(membership),
    );
  }

  DashboardMembership? _membershipFromRow(Map<String, dynamic>? row) {
    if (row == null) {
      return null;
    }

    final organization = row['organizations'];

    return DashboardMembership(
      role: _readString(row, 'role') ?? 'boarder',
      organizationName:
          _organizationNameFromValue(organization) ?? 'Apartment record',
    );
  }

  String? _organizationNameFromValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return _readString(value, 'name');
    }

    if (value is List && value.isNotEmpty) {
      final firstValue = value.first;
      if (firstValue is Map<String, dynamic>) {
        return _readString(firstValue, 'name');
      }
    }

    return null;
  }

  String? _readString(Map<String, dynamic>? row, String key) {
    final value = row?[key];
    if (value is! String) {
      return null;
    }

    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.displayName,
    required this.email,
    this.membership,
  });

  final String displayName;
  final String email;
  final DashboardMembership? membership;

  String get primaryIdentityLabel =>
      displayName.isNotEmpty ? displayName : email;

  String get roleLabel => membership?.roleLabel ?? 'Setup needed';

  String get roleDescription {
    final activeMembership = membership;
    if (activeMembership == null) {
      return 'Create or join an apartment before tracking dues.';
    }

    return activeMembership.isOwner
        ? 'You can manage dues, boarders, and payment proofs.'
        : 'You can view dues, upload proof, and track history.';
  }

  String get apartmentLabel =>
      membership?.organizationName.trim().isNotEmpty == true
      ? membership!.organizationName
      : 'No apartment yet';

  String get apartmentDescription {
    if (membership == null) {
      return 'Start owner onboarding to create the apartment record.';
    }

    return 'This is the apartment connected to your account.';
  }
}

class DashboardMembership {
  const DashboardMembership({
    required this.role,
    required this.organizationName,
  });

  final String role;
  final String organizationName;

  bool get isOwner => role.toLowerCase() == 'owner';

  String get roleLabel => isOwner ? 'Owner' : 'Boarder';

  IconData get roleIcon => isOwner ? Icons.apartment : Icons.person_outline;
}
