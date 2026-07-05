import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Sign in with email + password. Throws [AuthException] on failure.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Register a new account, then insert a profile row with [name].
  /// Returns `true` if the user is immediately active (no email confirmation
  /// needed), or `false` if Supabase sent a confirmation email first.
  /// Throws [AuthException] on failure.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );

    final userId = response.user?.id;
    if (userId != null) {
      // Store extra profile info — best-effort, ignore if profiles table
      // doesn't exist yet.
      try {
        await _client.from('profiles').upsert({
          'id': userId,
          'full_name': name,
          'email': email,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    // session is null when Supabase requires email confirmation first.
    return response.session != null;
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Currently authenticated user, null if not signed in.
  User? get currentUser => _client.auth.currentUser;

  /// Fetches the role for the currently signed-in user from the `profiles`
  /// table. Returns `'user'` as the default if the row or column is missing.
  Future<String> getUserRole() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 'user';
    try {
      final data = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return (data?['role'] as String?) ?? 'user';
    } catch (_) {
      return 'user';
    }
  }
}
