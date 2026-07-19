import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/demo_data.dart';
import 'demo_seed_service.dart';
import 'family_service.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Sign in with email + password. Throws [AuthException] on failure.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
    if (isDemoUser) {
      await DemoSeedService().seedIfNeeded();
    }
  }

  /// True when the signed-in user is the shared demo account.
  bool get isDemoUser {
    final email = currentUser?.email?.toLowerCase();
    return email == DemoAccount.email.toLowerCase();
  }

  /// Display name for the current user — profiles row, then auth metadata,
  /// then the email local-part, then a generic fallback.
  Future<String> getDisplayName() async {
    final user = currentUser;
    if (user == null) return 'User';

    try {
      final data = await getProfile();
      final fromProfile = (data?['full_name'] as String?)?.trim();
      if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    } catch (_) {}

    final fromMeta =
        (user.userMetadata?['full_name'] as String?)?.trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;

    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'User';
  }

  /// Nickname for greetings — profiles nickname, then full_name, then "there".
  Future<String> getGreetingName() async {
    try {
      final data = await getProfile();
      final nickname = (data?['nickname'] as String?)?.trim();
      if (nickname != null && nickname.isNotEmpty) return nickname;
      final fullName = (data?['full_name'] as String?)?.trim();
      if (fullName != null && fullName.isNotEmpty) return fullName;
    } catch (_) {}
    return 'there';
  }

  /// First word of the display name — used in greetings.
  Future<String> getFirstName() async {
    final full = await getDisplayName();
    final trimmed = full.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Sign in using the demo account. Creates the account on first use, then
  /// ensures it belongs to a demo family so the app opens with data context.
  Future<void> signInDemo() async {
    try {
      await signIn(email: DemoAccount.email, password: DemoAccount.password);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      final missing = msg.contains('invalid') ||
          msg.contains('credentials') ||
          msg.contains('not found');
      if (!missing) rethrow;

      final active = await signUp(
        name: DemoAccount.displayName,
        email: DemoAccount.email,
        password: DemoAccount.password,
      );
      if (!active) {
        throw AuthException(
          'Demo account could not be activated. Disable email confirmation in Supabase.',
        );
      }
      await signIn(email: DemoAccount.email, password: DemoAccount.password);
    }

    await _ensureDemoFamily();
    await DemoSeedService().seedIfNeeded();
  }

  Future<void> _ensureDemoFamily() async {
    if (!isDemoUser) return;
    final familyId = await FamilyService().myFamilyId();
    if (familyId != null) return;
    await FamilyService().createFamily(DemoAccount.familyName);
  }

  /// Register a new account, then insert a profile row with [name].
  /// Returns `true` if the user is immediately active (no email confirmation
  /// needed), or `false` if Supabase sent a confirmation email first.
  /// Throws [AuthException] on failure.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? nickname,
    String? phone,
    String? relation,
    String? country,
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
          'nickname': nickname?.trim() ?? '',
          'phone': phone?.trim() ?? '',
          'relation': relation,
          'country': country,
          'email': email,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    // session is null when Supabase requires email confirmation first.
    return response.session != null;
  }

  /// Permanently deletes the current user's account. Signs out locally
  /// afterward regardless of the call's outcome, since the session is no
  /// longer valid either way once the account is gone.
  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke('delete-account');
    if (response.status != 200) {
      final err =
          (response.data is Map) ? response.data['error'] : response.data;
      throw Exception(err?.toString() ?? 'Failed to delete account');
    }
    await _client.auth.signOut();
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Currently authenticated user, null if not signed in.
  User? get currentUser => _client.auth.currentUser;

  /// Fetches the current user's row from the `profiles` table.
  /// Returns null if no user is signed in.
  Future<Map<String, dynamic>?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  /// Upserts the editable profile fields for the current user, keyed by their
  /// auth id. No-op if not signed in. Throws on failure.
  Future<void> updateProfile({
    required String fullName,
    String? nickname,
    String? phone,
    String? relation,
    String? country,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'nickname': nickname?.trim() ?? '',
      'phone': phone,
      'relation': relation,
      'country': country,
    });
  }

  /// Upserts just the avatar path for the current user — kept separate
  /// from [updateProfile] so uploading a photo doesn't require the user
  /// to also save the rest of the form. Safe against clobbering other
  /// fields since only `avatar_path` is included in the upsert.
  Future<void> updateAvatarPath(String? avatarPath) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('profiles').upsert({
      'id': userId,
      'avatar_path': avatarPath,
    });
  }

  /// Upserts the base escalation delay (seconds) used by [AlertService].
  /// Kept separate from [updateProfile] for the same reason as
  /// [updateAvatarPath] — a settings slider shouldn't require saving the
  /// whole profile form. Server-side check constrains this to 30-90s.
  Future<void> updateAlertTimerSeconds(int seconds) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('profiles').upsert({
      'id': userId,
      'alert_timer_seconds': seconds,
    });
  }

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
