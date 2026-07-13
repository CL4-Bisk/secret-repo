import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepositoryContract>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final authUserChangesProvider = StreamProvider<AuthUserSnapshot?>((ref) async* {
  final repository = ref.watch(authRepositoryProvider);

  yield repository.currentUserSnapshot;
  yield* repository.authStateChanges;
});

enum AuthIntendedRole {
  owner('owner'),
  boarder('boarder');

  const AuthIntendedRole(this.value);

  final String value;

  static AuthIntendedRole? fromValue(Object? value) {
    final normalizedValue = value?.toString().trim().toLowerCase();

    for (final role in AuthIntendedRole.values) {
      if (role.value == normalizedValue) {
        return role;
      }
    }

    return null;
  }
}

class AuthUserSnapshot {
  const AuthUserSnapshot({
    required this.id,
    required this.email,
    this.intendedRole,
  });

  final String id;
  final String? email;
  final AuthIntendedRole? intendedRole;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthUserSnapshot &&
            other.id == id &&
            other.email == email &&
            other.intendedRole == intendedRole;
  }

  @override
  int get hashCode => Object.hash(id, email, intendedRole);
}

abstract interface class AuthRepositoryContract {
  bool get isSignedIn;

  String? get currentUserId;

  String? get currentUserEmail;

  AuthIntendedRole? get currentUserIntendedRole;

  AuthUserSnapshot? get currentUserSnapshot;

  Stream<AuthUserSnapshot?> get authStateChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required AuthIntendedRole intendedRole,
  });
}

class AuthRepository implements AuthRepositoryContract {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  AuthIntendedRole? get currentUserIntendedRole {
    final metadata = _client.auth.currentUser?.userMetadata;

    return AuthIntendedRole.fromValue(metadata?['intended_role']);
  }

  @override
  AuthUserSnapshot? get currentUserSnapshot {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    return AuthUserSnapshot(
      id: user.id,
      email: user.email,
      intendedRole: currentUserIntendedRole,
    );
  }

  @override
  Stream<AuthUserSnapshot?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((_) => currentUserSnapshot);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required AuthIntendedRole intendedRole,
  }) async {
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'intended_role': intendedRole.value},
    );
  }
}
