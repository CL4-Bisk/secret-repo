import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';
import 'payment_proof_picker.dart';

final dashboardRepositoryProvider = Provider<DashboardRepositoryContract>((
  ref,
) {
  return DashboardRepository(
    client: ref.watch(supabaseClientProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) {
  ref.watch(authUserChangesProvider);

  return ref.watch(dashboardRepositoryProvider).fetchSummary();
});

final transactionHistoryProvider = FutureProvider<TransactionHistory>((ref) {
  ref.watch(authUserChangesProvider);

  return ref.watch(dashboardRepositoryProvider).fetchTransactionHistory();
});

abstract interface class DashboardRepositoryContract {
  Future<DashboardSummary> fetchSummary();

  Future<TransactionHistory> fetchTransactionHistory();

  Future<void> createOwnerApartment({required String name});

  Future<String> createOwnerInvite();

  Future<void> joinWithInviteCode({required String code});

  Future<void> createDue({
    required String boarderUserId,
    required String title,
    required int amountCentavos,
    required DateTime dueDate,
  });

  Future<void> submitPaymentProof({
    required DashboardDue due,
    required PickedPaymentProofFile file,
  });

  Future<void> reviewPaymentProof({
    required String proofId,
    required bool approved,
    String? rejectionReason,
    String? rejectionNote,
  });
}

class DashboardRepository implements DashboardRepositoryContract {
  static const membershipUserIdColumn = 'user_id';
  static const paymentProofBucket = 'payment-proofs';
  static const _maxProofImageDimension = 1200;
  static const _maxProofImageBytes = 1024 * 1024;
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
    final intendedRole = authRepository.currentUserIntendedRole;

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
    final paymentProofs =
        activeMembership?.isOwner == true &&
            activeMembership?.organizationId != null
        ? await _fetchPaymentProofs(
            organizationId: activeMembership!.organizationId!,
          )
        : const <DashboardPaymentProof>[];

    return DashboardSummary(
      displayName: _readString(profile, 'full_name') ?? email,
      email: email,
      intendedRole: intendedRole,
      membership: activeMembership,
      boarders: boarders,
      dues: dues,
      paymentProofs: paymentProofs,
    );
  }

  @override
  Future<TransactionHistory> fetchTransactionHistory() async {
    final summary = await fetchSummary();
    final membership = summary.membership;
    final organizationId = membership?.organizationId;

    if (organizationId == null) {
      return TransactionHistory(summary: summary);
    }

    if (membership?.isOwner == true) {
      return TransactionHistory(
        summary: summary,
        boarders: summary.boarders,
        dues: summary.dues,
        paymentProofs: summary.paymentProofs,
      );
    }

    final userId = authRepository.currentUserId;
    final paymentProofs = userId == null
        ? const <DashboardPaymentProof>[]
        : await _fetchPaymentProofs(
            organizationId: organizationId,
            boarderUserId: userId,
          );

    return TransactionHistory(
      summary: summary,
      dues: summary.dues,
      paymentProofs: paymentProofs,
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

  @override
  Future<void> submitPaymentProof({
    required DashboardDue due,
    required PickedPaymentProofFile file,
  }) async {
    final userId = authRepository.currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to submit a payment proof.');
    }

    final preparedImage = preparePaymentProofImage(
      bytes: file.bytes,
      fileName: file.fileName,
    );
    final storagePath = paymentProofStoragePath(
      userId: userId,
      dueId: due.id,
    );

    await client.storage
        .from(paymentProofBucket)
        .uploadBinary(
          storagePath,
          preparedImage.bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    try {
      await client.rpc(
        'submit_payment_proof',
        params: submitPaymentProofRpcParams(
          dueId: due.id,
          storagePath: storagePath,
          amountCentavos: due.amountCentavos,
          originalFileName: file.fileName,
        ),
      );
    } catch (_) {
      await _removeUploadedProofIfUnused(storagePath);
      rethrow;
    }
  }

  @override
  Future<void> reviewPaymentProof({
    required String proofId,
    required bool approved,
    String? rejectionReason,
    String? rejectionNote,
  }) async {
    final userId = authRepository.currentUserId;
    if (userId == null) {
      throw StateError('You must be signed in to review a payment proof.');
    }

    await client.rpc(
      'review_payment_proof',
      params: reviewPaymentProofRpcParams(
        proofId: proofId,
        approved: approved,
        rejectionReason: rejectionReason,
        rejectionNote: rejectionNote,
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

  Future<List<DashboardPaymentProof>> _fetchPaymentProofs({
    required String organizationId,
    String? boarderUserId,
  }) async {
    const columns = '''
id,
due_id,
organization_id,
boarder_user_id,
storage_path,
amount_centavos,
status,
submitted_at,
reviewed_at,
rejection_reason,
rejection_note,
dues(title),
profiles!payment_proofs_boarder_user_id_fkey(full_name)
''';

    final baseQuery = client
        .from('payment_proofs')
        .select(columns)
        .eq('organization_id', organizationId);
    final rows = boarderUserId == null
        ? await baseQuery.order('submitted_at', ascending: false)
        : await baseQuery
              .eq('boarder_user_id', boarderUserId)
              .order('submitted_at', ascending: false);

    final proofs = <DashboardPaymentProof>[];
    for (final row in rows) {
      final storagePath = _readString(row, 'storage_path');
      final signedUrl = storagePath == null
          ? null
          : await client.storage
                .from(paymentProofBucket)
                .createSignedUrl(storagePath, 60 * 60);
      proofs.add(paymentProofFromRow(row, signedUrl: signedUrl));
    }

    return proofs;
  }

  Future<void> _removeUploadedProofIfUnused(String storagePath) async {
    try {
      await client.storage.from(paymentProofBucket).remove([storagePath]);
    } catch (_) {
      // The database error is more useful to the user than cleanup failure.
    }
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

  static PreparedPaymentProofImage preparePaymentProofImage({
    required Uint8List bytes,
    required String fileName,
  }) {
    final extension = _fileExtension(fileName);
    if (!{'jpg', 'jpeg', 'png'}.contains(extension)) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'Please upload a JPG or PNG receipt image.',
      );
    }

    final decodedImage = image.decodeImage(bytes);
    if (decodedImage == null) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'The selected file is not a readable image.',
      );
    }

    var resizedImage = _resizeProofImage(decodedImage, _maxProofImageDimension);
    var quality = 70;
    var encodedBytes = Uint8List.fromList(
      image.encodeJpg(resizedImage, quality: quality),
    );

    while (encodedBytes.length > _maxProofImageBytes && quality > 45) {
      quality -= 10;
      encodedBytes = Uint8List.fromList(
        image.encodeJpg(resizedImage, quality: quality),
      );
    }

    if (encodedBytes.length > _maxProofImageBytes) {
      resizedImage = _resizeProofImage(resizedImage, 900);
      encodedBytes = Uint8List.fromList(
        image.encodeJpg(resizedImage, quality: 50),
      );
    }

    if (encodedBytes.length > _maxProofImageBytes) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'The image is still larger than 1 MB after compression.',
      );
    }

    return PreparedPaymentProofImage(
      bytes: encodedBytes,
      contentType: 'image/jpeg',
      extension: 'jpg',
    );
  }

  static String paymentProofStoragePath({
    required String userId,
    required String dueId,
    DateTime? timestamp,
  }) {
    final normalizedUserId = userId.trim();
    final normalizedDueId = dueId.trim();
    final timestampPart =
        (timestamp ?? DateTime.now().toUtc()).toUtc().millisecondsSinceEpoch;

    return '$normalizedUserId/$normalizedDueId-$timestampPart.jpg';
  }

  static Map<String, Object> submitPaymentProofRpcParams({
    required String dueId,
    required String storagePath,
    required int amountCentavos,
    required String originalFileName,
  }) {
    return {
      'p_due_id': dueId,
      'p_storage_path': storagePath.trim(),
      'p_amount_centavos': amountCentavos,
      'p_original_file_name': originalFileName.trim(),
    };
  }

  static Map<String, Object?> reviewPaymentProofRpcParams({
    required String proofId,
    required bool approved,
    String? rejectionReason,
    String? rejectionNote,
  }) {
    final params = <String, Object?>{
      'p_proof_id': proofId,
      'p_status': approved ? 'approved' : 'rejected',
    };

    if (approved) {
      return params;
    }

    final trimmedReason = rejectionReason?.trim();
    if (trimmedReason == null || trimmedReason.isEmpty) {
      throw ArgumentError.value(
        rejectionReason,
        'rejectionReason',
        'Choose a rejection reason before rejecting the proof.',
      );
    }

    params['p_rejection_reason'] = trimmedReason;

    final trimmedNote = rejectionNote?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      params['p_rejection_note'] = trimmedNote;
    }

    return params;
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

  static DashboardPaymentProof paymentProofFromRow(
    Map<String, dynamic> row, {
    String? signedUrl,
  }) {
    final due = _embeddedMapFromValue(row['dues']);
    final profile = _embeddedMapFromValue(row['profiles']);
    final boarderUserId =
        _readString(row, 'boarder_user_id') ?? 'Unknown boarder';

    return DashboardPaymentProof(
      id: _readString(row, 'id') ?? '',
      dueId: _readString(row, 'due_id') ?? '',
      organizationId: _readString(row, 'organization_id') ?? '',
      boarderUserId: boarderUserId,
      boarderName: _readString(profile, 'full_name') ?? boarderUserId,
      dueTitle: _readString(due, 'title') ?? 'Untitled due',
      amountCentavos: _readInt(row, 'amount_centavos') ?? 0,
      status: _readString(row, 'status') ?? 'pending',
      storagePath: _readString(row, 'storage_path') ?? '',
      submittedAt:
          _readDateTime(row, 'submitted_at') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      reviewedAt: _readDateTime(row, 'reviewed_at'),
      rejectionReason: _readString(row, 'rejection_reason'),
      rejectionNote: _readString(row, 'rejection_note'),
      signedUrl: signedUrl,
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

  static image.Image _resizeProofImage(image.Image source, int maxDimension) {
    final longestSide = max(source.width, source.height);
    if (longestSide <= maxDimension) {
      return source;
    }

    if (source.width >= source.height) {
      return image.copyResize(source, width: maxDimension);
    }

    return image.copyResize(source, height: maxDimension);
  }

  static String _fileExtension(String fileName) {
    final parts = fileName.trim().split('.');
    if (parts.length < 2) {
      return '';
    }

    return parts.last.toLowerCase();
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

  static DateTime? _readDateTime(Map<String, dynamic>? row, String key) {
    final value = row?[key];
    if (value is DateTime) {
      return value.toUtc();
    }

    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
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
    this.intendedRole,
    this.membership,
    this.boarders = const [],
    this.dues = const [],
    this.paymentProofs = const [],
  });

  final String displayName;
  final String email;
  final AuthIntendedRole? intendedRole;
  final DashboardMembership? membership;
  final List<DashboardBoarder> boarders;
  final List<DashboardDue> dues;
  final List<DashboardPaymentProof> paymentProofs;

  String get primaryIdentityLabel =>
      displayName.isNotEmpty ? displayName : email;

  String get roleLabel {
    final activeMembership = membership;
    if (activeMembership != null) {
      return activeMembership.roleLabel;
    }

    return switch (intendedRole) {
      AuthIntendedRole.owner => 'Owner setup needed',
      AuthIntendedRole.boarder => 'Boarder setup needed',
      null => 'Setup needed',
    };
  }

  String get roleDescription {
    final activeMembership = membership;
    if (activeMembership == null) {
      return switch (intendedRole) {
        AuthIntendedRole.owner =>
          'Create your apartment before inviting boarders.',
        AuthIntendedRole.boarder =>
          'Join your apartment with the owner invite code.',
        null => 'This account has no saved owner or boarder role.',
      };
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
      return switch (intendedRole) {
        AuthIntendedRole.owner =>
          'Create the apartment record for your account.',
        AuthIntendedRole.boarder =>
          'Join with the invite code from your owner.',
        null =>
          'Sign out and use the correct signup path, or update this user role metadata.',
      };
    }

    return 'This is the apartment connected to your account.';
  }
}

class TransactionHistory {
  const TransactionHistory({
    required this.summary,
    this.boarders = const [],
    this.dues = const [],
    this.paymentProofs = const [],
  });

  final DashboardSummary summary;
  final List<DashboardBoarder> boarders;
  final List<DashboardDue> dues;
  final List<DashboardPaymentProof> paymentProofs;

  bool get isOwner => summary.membership?.isOwner == true;
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

  bool get canSubmitProof {
    return switch (status.toLowerCase()) {
      'unpaid' || 'rejected' => true,
      _ => false,
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

class PreparedPaymentProofImage {
  const PreparedPaymentProofImage({
    required this.bytes,
    required this.contentType,
    required this.extension,
  });

  final Uint8List bytes;
  final String contentType;
  final String extension;
}

enum PaymentProofRejectionReason {
  invalidReceipt('invalid_receipt', 'Invalid receipt'),
  expiredReceipt('expired_receipt', 'Expired receipt'),
  wrongAmount('wrong_amount', 'Wrong amount'),
  wrongDue('wrong_due', 'Wrong due'),
  unclearImage('unclear_image', 'Unclear image'),
  duplicatePayment('duplicate_payment', 'Duplicate payment'),
  other('other', 'Other');

  const PaymentProofRejectionReason(this.code, this.label);

  final String code;
  final String label;

  static PaymentProofRejectionReason? fromCode(String? code) {
    final normalizedCode = code?.trim().toLowerCase();

    for (final reason in values) {
      if (reason.code == normalizedCode) {
        return reason;
      }
    }

    return null;
  }
}

class DashboardPaymentProof {
  const DashboardPaymentProof({
    required this.id,
    required this.dueId,
    required this.organizationId,
    required this.boarderUserId,
    required this.boarderName,
    required this.dueTitle,
    required this.amountCentavos,
    required this.status,
    required this.storagePath,
    required this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.rejectionNote,
    this.signedUrl,
  });

  final String id;
  final String dueId;
  final String organizationId;
  final String boarderUserId;
  final String boarderName;
  final String dueTitle;
  final int amountCentavos;
  final String status;
  final String storagePath;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? rejectionNote;
  final String? signedUrl;

  bool get isPending => status.toLowerCase() == 'pending';

  String get amountLabel {
    final pesos = amountCentavos ~/ 100;
    final centavos = amountCentavos % 100;

    return 'P${DashboardDue._formatThousands(pesos)}.${centavos.toString().padLeft(2, '0')}';
  }

  String get statusLabel {
    return switch (status.toLowerCase()) {
      'pending' => 'Pending',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => status,
    };
  }

  String get rejectionReasonLabel {
    final reason = PaymentProofRejectionReason.fromCode(rejectionReason);
    if (reason != null) {
      return reason.label;
    }

    return rejectionReason?.trim().isNotEmpty == true
        ? rejectionReason!.trim()
        : 'No reason provided';
  }

  String get submittedAtLabel {
    final utc = submittedAt.toUtc();

    return [
      utc.year.toString().padLeft(4, '0'),
      utc.month.toString().padLeft(2, '0'),
      utc.day.toString().padLeft(2, '0'),
    ].join('-');
  }
}
