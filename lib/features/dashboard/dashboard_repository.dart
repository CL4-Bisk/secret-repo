import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepositoryContract>((
  ref,
) {
  return DashboardRepository(
    client: ref.watch(supabaseClientProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) {
  return ref.watch(dashboardRepositoryProvider).fetchSummary();
});

abstract interface class DashboardRepositoryContract {
  Future<DashboardSummary> fetchSummary();

  Future<void> createOwnerApartment({required String name});

  Future<String> createOwnerInvite();

  Future<void> joinWithInviteCode({required String code});

  Future<void> createDue({
    required String boarderUserId,
    required String title,
    required int amountCentavos,
    required DateTime dueDate,
  });
}

class DashboardRepository implements DashboardRepositoryContract {
  static const membershipUserIdColumn = 'user_id';
  static const _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  const DashboardRepository({
    required this.client,
    required this.authRepository,
  });

  final SupabaseClient client;
  final AuthRepository authRepository;

  @override
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
    final activeMembership = _membershipFromRow(membership);
    final boarders =
        activeMembership?.isOwner == true &&
            activeMembership?.organizationId != null
        ? await _fetchBoarders(
            organizationId: activeMembership!.organizationId!,
          )
        : const <DashboardBoarder>[];
    final dues = activeMembership?.organizationId != null
        ? await _fetchDues(
            organizationId: activeMembership!.organizationId!,
            boarderUserId: activeMembership.isOwner ? null : userId,
          )
        : const <DashboardDue>[];

    return DashboardSummary(
      displayName: _readString(profile, 'full_name') ?? email,
      email: email,
      membership: activeMembership,
      boarders: boarders,
      dues: dues,
    );
  }

  @override
  Future<void> createOwnerApartment({required String name}) async {
    final userId = authRepository.currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to create an apartment.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Apartment name is required.');
    }

    await _ensureCurrentUserProfile(userId: userId);

    final organization = await client
        .from('organizations')
        .insert(ownerOrganizationInsert(name: trimmedName, userId: userId))
        .select('id')
        .single();
    final organizationId = _readString(organization, 'id');

    if (organizationId == null) {
      throw StateError('Supabase did not return the new apartment id.');
    }

    await client
        .from('memberships')
        .insert(
          ownerMembershipInsert(organizationId: organizationId, userId: userId),
        );
  }

  @override
  Future<String> createOwnerInvite() async {
    final userId = authRepository.currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to create an invite.');
    }

    await _ensureCurrentUserProfile(userId: userId);

    final organizationId = await _currentOwnerOrganizationId(userId: userId);
    final code = generateInviteCode();
    final expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));

    await client
        .from('organization_invites')
        .insert(
          ownerInviteInsert(
            organizationId: organizationId,
            userId: userId,
            code: code,
            expiresAt: expiresAt,
          ),
        );

    return code;
  }

  @override
  Future<void> joinWithInviteCode({required String code}) async {
    final userId = authRepository.currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to join an apartment.');
    }

    final normalizedCode = normalizeInviteCode(code);
    if (normalizedCode.length != 9) {
      throw ArgumentError.value(code, 'code', 'Enter a complete invite code.');
    }

    await _ensureCurrentUserProfile(userId: userId);
    await client.rpc(
      'join_organization_with_invite',
      params: joinInviteRpcParams(normalizedCode),
    );
  }

  @override
  Future<void> createDue({
    required String boarderUserId,
    required String title,
    required int amountCentavos,
    required DateTime dueDate,
  }) async {
    final userId = authRepository.currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to create dues.');
    }

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Due title is required.');
    }

    if (amountCentavos <= 0) {
      throw ArgumentError.value(
        amountCentavos,
        'amountCentavos',
        'Due amount must be greater than zero.',
      );
    }

    final organizationId = await _currentOwnerOrganizationId(userId: userId);

    await client
        .from('dues')
        .insert(
          ownerDueInsert(
            organizationId: organizationId,
            boarderUserId: boarderUserId,
            createdBy: userId,
            title: trimmedTitle,
            amountCentavos: amountCentavos,
            dueDate: dueDate,
          ),
        );
  }

  Future<String> _currentOwnerOrganizationId({required String userId}) async {
    final membership = await client
        .from('memberships')
        .select('organization_id')
        .eq(membershipUserIdColumn, userId)
        .eq('role', 'owner')
        .limit(1)
        .maybeSingle();
    final organizationId = _readString(membership, 'organization_id');

    if (organizationId == null) {
      throw StateError('Create an apartment before inviting boarders.');
    }

    return organizationId;
  }

  Future<List<DashboardBoarder>> _fetchBoarders({
    required String organizationId,
  }) async {
    final rows = await client
        .from('memberships')
        .select(
          'id, organization_id, user_id, created_at, profiles(full_name, phone)',
        )
        .eq('organization_id', organizationId)
        .eq('role', 'boarder')
        .order('created_at', ascending: true);

    return [for (final row in rows) boarderFromRow(row)];
  }

  Future<List<DashboardDue>> _fetchDues({
    required String organizationId,
    required String? boarderUserId,
  }) async {
    const columns = '''
id,
organization_id,
boarder_user_id,
title,
description,
amount_centavos,
due_date,
status,
profiles!dues_boarder_user_id_fkey(full_name)
''';

    final baseQuery = client
        .from('dues')
        .select(columns)
        .eq('organization_id', organizationId);
    final rows = boarderUserId == null
        ? await baseQuery.order('due_date', ascending: true)
        : await baseQuery
              .eq('boarder_user_id', boarderUserId)
              .order('due_date', ascending: true);

    return [for (final row in rows) dueFromRow(row)];
  }

  Future<void> _ensureCurrentUserProfile({required String userId}) async {
    final profile = await client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();

    if (profile != null) {
      return;
    }

    await client
        .from('profiles')
        .insert(
          currentUserProfileInsert(
            userId: userId,
            fallbackName: authRepository.currentUserEmail,
          ),
        );
  }

  static Map<String, Object> currentUserProfileInsert({
    required String userId,
    required String? fallbackName,
  }) {
    final trimmedName = fallbackName?.trim();

    return {
      'id': userId,
      'full_name': trimmedName == null || trimmedName.isEmpty
          ? 'New user'
          : trimmedName,
    };
  }

  static String generateInviteCode([Random? random]) {
    final source = random ?? Random.secure();

    String segment() {
      return String.fromCharCodes(
        List.generate(4, (_) {
          final index = source.nextInt(_inviteAlphabet.length);
          return _inviteAlphabet.codeUnitAt(index);
        }),
      );
    }

    return '${segment()}-${segment()}';
  }

  static String normalizeInviteCode(String code) {
    final compactCode = code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final limitedCode = compactCode.length > 8
        ? compactCode.substring(0, 8)
        : compactCode;

    if (limitedCode.length <= 4) {
      return limitedCode;
    }

    return '${limitedCode.substring(0, 4)}-${limitedCode.substring(4)}';
  }

  static Map<String, Object> ownerInviteInsert({
    required String organizationId,
    required String userId,
    required String code,
    required DateTime expiresAt,
  }) {
    return {
      'organization_id': organizationId,
      'created_by': userId,
      'code': normalizeInviteCode(code),
      'expires_at': expiresAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, Object> joinInviteRpcParams(String code) {
    return {'invite_code': normalizeInviteCode(code)};
  }

  static Map<String, Object> ownerDueInsert({
    required String organizationId,
    required String boarderUserId,
    required String createdBy,
    required String title,
    required int amountCentavos,
    required DateTime dueDate,
  }) {
    return {
      'organization_id': organizationId,
      'boarder_user_id': boarderUserId,
      'created_by': createdBy,
      'title': title.trim(),
      'amount_centavos': amountCentavos,
      'due_date': _formatDate(dueDate),
      'status': 'unpaid',
    };
  }

  static Map<String, Object> ownerOrganizationInsert({
    required String name,
    required String userId,
  }) {
    return {'name': name.trim(), 'created_by': userId};
  }

  static Map<String, Object> ownerMembershipInsert({
    required String organizationId,
    required String userId,
  }) {
    return {
      'organization_id': organizationId,
      membershipUserIdColumn: userId,
      'role': 'owner',
    };
  }

  static DashboardBoarder boarderFromRow(Map<String, dynamic> row) {
    final profile = _embeddedMapFromValue(row['profiles']);
    final userId = _readString(row, membershipUserIdColumn) ?? 'Unknown user';

    return DashboardBoarder(
      membershipId: _readString(row, 'id') ?? '',
      userId: userId,
      displayName: _readString(profile, 'full_name') ?? userId,
      phone: _readString(profile, 'phone'),
    );
  }

  static DashboardDue dueFromRow(Map<String, dynamic> row) {
    final profile = _embeddedMapFromValue(row['profiles']);
    final boarderUserId =
        _readString(row, 'boarder_user_id') ?? 'Unknown boarder';

    return DashboardDue(
      id: _readString(row, 'id') ?? '',
      organizationId: _readString(row, 'organization_id') ?? '',
      boarderUserId: boarderUserId,
      boarderName: _readString(profile, 'full_name') ?? boarderUserId,
      title: _readString(row, 'title') ?? 'Untitled due',
      description: _readString(row, 'description'),
      amountCentavos: _readInt(row, 'amount_centavos') ?? 0,
      dueDate: _readDate(row, 'due_date') ?? DateTime.utc(1970),
      status: _readString(row, 'status') ?? 'unpaid',
    );
  }

  DashboardMembership? _membershipFromRow(Map<String, dynamic>? row) {
    if (row == null) {
      return null;
    }

    final organization = _embeddedMapFromValue(row['organizations']);

    return DashboardMembership(
      role: _readString(row, 'role') ?? 'boarder',
      organizationId:
          _readString(row, 'organization_id') ??
          _readString(organization, 'id'),
      organizationName: _readString(organization, 'name') ?? 'Apartment record',
    );
  }

  static Map<String, dynamic>? _embeddedMapFromValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is List && value.isNotEmpty) {
      final firstValue = value.first;
      if (firstValue is Map<String, dynamic>) {
        return firstValue;
      }
    }

    return null;
  }

  static String? _readString(Map<String, dynamic>? row, String key) {
    final value = row?[key];
    if (value is! String) {
      return null;
    }

    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }

  static int? _readInt(Map<String, dynamic>? row, String key) {
    final value = row?[key];
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  static DateTime? _readDate(Map<String, dynamic>? row, String key) {
    final value = row?[key];
    if (value is DateTime) {
      return DateTime.utc(value.year, value.month, value.day);
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null) {
        return null;
      }

      return DateTime.utc(parsed.year, parsed.month, parsed.day);
    }

    return null;
  }

  static String _formatDate(DateTime date) {
    final normalized = DateTime.utc(date.year, date.month, date.day);

    return [
      normalized.year.toString().padLeft(4, '0'),
      normalized.month.toString().padLeft(2, '0'),
      normalized.day.toString().padLeft(2, '0'),
    ].join('-');
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.displayName,
    required this.email,
    this.membership,
    this.boarders = const [],
    this.dues = const [],
  });

  final String displayName;
  final String email;
  final DashboardMembership? membership;
  final List<DashboardBoarder> boarders;
  final List<DashboardDue> dues;

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
      return 'Join with an invite code or open owner setup if you manage the apartment.';
    }

    return 'This is the apartment connected to your account.';
  }
}

class DashboardMembership {
  const DashboardMembership({
    required this.role,
    required this.organizationName,
    this.organizationId,
  });

  final String role;
  final String organizationName;
  final String? organizationId;

  bool get isOwner => role.toLowerCase() == 'owner';

  String get roleLabel => isOwner ? 'Owner' : 'Boarder';

  IconData get roleIcon => isOwner ? Icons.apartment : Icons.person_outline;
}

class DashboardBoarder {
  const DashboardBoarder({
    required this.membershipId,
    required this.userId,
    required this.displayName,
    this.phone,
  });

  final String membershipId;
  final String userId;
  final String displayName;
  final String? phone;

  String get phoneLabel =>
      phone?.trim().isNotEmpty == true ? phone!.trim() : 'No phone yet';
}

class DashboardDue {
  const DashboardDue({
    required this.id,
    required this.organizationId,
    required this.boarderUserId,
    required this.boarderName,
    required this.title,
    required this.amountCentavos,
    required this.dueDate,
    required this.status,
    this.description,
  });

  final String id;
  final String organizationId;
  final String boarderUserId;
  final String boarderName;
  final String title;
  final String? description;
  final int amountCentavos;
  final DateTime dueDate;
  final String status;

  String get amountLabel {
    final pesos = amountCentavos ~/ 100;
    final centavos = amountCentavos % 100;

    return 'P${_formatThousands(pesos)}.${centavos.toString().padLeft(2, '0')}';
  }

  String get dueDateLabel => [
    dueDate.year.toString().padLeft(4, '0'),
    dueDate.month.toString().padLeft(2, '0'),
    dueDate.day.toString().padLeft(2, '0'),
  ].join('-');

  String get statusLabel {
    return switch (status.toLowerCase()) {
      'unpaid' => 'Unpaid',
      'proof_submitted' => 'Proof submitted',
      'paid' => 'Paid',
      'rejected' => 'Rejected',
      _ => status,
    };
  }

  static String _formatThousands(int value) {
    final source = value.toString();
    final reversedCharacters = source.split('').reversed.toList();
    final chunks = <String>[];

    for (var index = 0; index < reversedCharacters.length; index += 3) {
      final end = min(index + 3, reversedCharacters.length);
      chunks.add(reversedCharacters.sublist(index, end).reversed.join());
    }

    return chunks.reversed.join(',');
  }
}
