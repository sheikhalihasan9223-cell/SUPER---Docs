import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';
import 'supabase_config.dart';
import 'profile_model.dart';

abstract class CloudDocuments {
  String? get userId;
  Future<List<DocFile>> list(
    String owner, {
    Map<String, DocFile> cached = const {},
  });
  Future<void> save(String owner, DocFile file);
  Future<void> remove(String owner, String id);
}

class SupabaseBackend extends ChangeNotifier
    implements CloudDocuments, ProfileAccount {
  final SupabaseClient client;
  final String url, publicKey;
  StreamSubscription<AuthState>? subscription;
  @override
  String? authError;
  SupabaseBackend(
    this.client, {
    required this.url,
    required this.publicKey,
    Stream<AuthState>? authEvents,
  }) {
    subscription = (authEvents ?? client.auth.onAuthStateChange).listen(
      (state) {
        if (state.session != null) authError = null;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        authError = error is AuthException
            ? authErrorMessage(error.message)
            : 'Google sign-in could not be completed. Please try again.';
        notifyListeners();
      },
    );
  }
  static String authErrorMessage(String message) {
    // Provider callbacks can include the authorization code. Never display it.
    if (message.toLowerCase().contains('unable to exchange external code')) {
      return 'Google sign-in could not be completed. The app administrator '
          'needs to check the Google login configuration.';
    }
    return message;
  }

  static SupabaseBackend? active;
  static Future<void> initialize() async {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: defaultSupabaseUrl,
    );
    const key = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: defaultSupabasePublishableKey,
    );
    if (url.isEmpty || key.isEmpty) return;
    if (key.startsWith('sb_secret_')) {
      throw StateError('Use a Supabase publishable key in Flutter.');
    }
    await Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    active = SupabaseBackend(
      Supabase.instance.client,
      url: url,
      publicKey: key,
    );
  }

  @override
  String? get userId => client.auth.currentUser?.id;
  String? get email => client.auth.currentUser?.email;
  @override
  AccountProfile? get profile {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata ?? {};
    final name =
        '${metadata['display_name'] ?? metadata['full_name'] ?? metadata['name'] ?? 'Your profile'}';
    final photo = Uri.tryParse(
      '${metadata['avatar_url'] ?? metadata['picture'] ?? ''}',
    );
    return AccountProfile(
      id: user.id,
      name: name,
      email: user.email ?? '',
      photoUrl: photo?.scheme == 'https' ? photo.toString() : null,
    );
  }

  @override
  Future<void> updateName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 80) {
      throw const FormatException('Use a name between 1 and 80 characters.');
    }
    if (client.auth.currentUser == null) {
      throw StateError('Sign in to edit your profile.');
    }
    await client.auth.updateUser(UserAttributes(data: {'display_name': clean}));
    notifyListeners();
  }

  String get functionEndpoint => '$url/functions/v1/docs-process';
  String? get token => client.auth.currentSession?.accessToken;
  @override
  Future<void> signIn() async {
    authError = null;
    notifyListeners();
    final launched = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb
          ? Uri.base.origin
          : 'com.superdocs.app://login-callback/',
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      queryParams: const {'prompt': 'select_account'},
    );
    if (!launched) {
      throw StateError('Could not open Google sign-in. Please try again.');
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut();
  void checkOwner(String owner) {
    if (owner != userId) {
      throw StateError('Your account changed. Please retry.');
    }
  }

  String objectPath(String owner, String id) =>
      '$owner/${Uri.encodeComponent(id)}';
  @override
  Future<List<DocFile>> list(
    String owner, {
    Map<String, DocFile> cached = const {},
  }) async {
    checkOwner(owner);
    final rows = await client
        .from('documents')
        .select()
        .eq('owner_id', owner)
        .order('created_at', ascending: false);
    final result = <DocFile>[];
    for (final row in rows) {
      checkOwner(owner);
      final bytes =
          cached[row['id']]?.bytes ??
          await client.storage.from('documents').download(row['object_path']);
      checkOwner(owner);
      result.add(
        DocFile(
          id: row['id'],
          name: row['name'],
          bytes: bytes,
          created: DateTime.parse(row['created_at']),
          tool: row['tool'],
          favorite: row['favorite'],
        ),
      );
    }
    return result;
  }

  @override
  Future<void> save(String owner, DocFile file) async {
    checkOwner(owner);
    final path = objectPath(owner, file.id);
    final existing = await client
        .from('documents')
        .select('id')
        .eq('owner_id', owner)
        .eq('id', file.id)
        .maybeSingle();
    checkOwner(owner);
    if (existing == null) {
      await client.storage
          .from('documents')
          .uploadBinary(
            path,
            file.bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'application/octet-stream',
            ),
          );
    }
    checkOwner(owner);
    await client.from('documents').upsert({
      'owner_id': owner,
      'id': file.id,
      'name': file.name,
      'object_path': path,
      'size_bytes': file.bytes.length,
      'created_at': file.created.toUtc().toIso8601String(),
      'tool': file.tool,
      'favorite': file.favorite,
    }, onConflict: 'owner_id,id');
  }

  @override
  Future<void> remove(String owner, String id) async {
    checkOwner(owner);
    await client.storage.from('documents').remove([objectPath(owner, id)]);
    checkOwner(owner);
    await client.from('documents').delete().eq('owner_id', owner).eq('id', id);
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }
}
