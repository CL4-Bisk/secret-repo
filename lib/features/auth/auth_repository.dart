import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final authUserChangesProvider = StreamProvider<AuthUserSnapshot?>((ref) async* {
  final repository = ref.watch(authRepositoryProvider);

  yield repository.currentUserSnapshot;
  yield* repository.authStateChanges;
});

class AuthUserSnapshot {
  const AuthUserSnapshot({required this.id, required this.email});

  final String id;
  final String? email;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthUserSnapshot && other.id == id && other.email == email;
  }

  @override
  int get hashCode => Object.hash(id, email);
}

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  bool get isSignedIn => _client.auth.currentSession != null;

  String? get currentUserId => _client.auth.currentUser?.id;

  String? get currentUserEmail => _client.auth.currentUser?.email;

  AuthUserSnapshot? get currentUserSnapshot {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    return AuthUserSnapshot(id: user.id, email: user.email);
  }

  Stream<AuthUserSnapshot?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((_) => currentUserSnapshot);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> signUpOwner({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
  }
}
