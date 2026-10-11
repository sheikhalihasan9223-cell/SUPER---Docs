import 'package:flutter/foundation.dart';

class AccountProfile {
  final String id, name, email;
  final String? photoUrl;
  const AccountProfile({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });
  String get initial => name.trim().isEmpty
      ? 'S'
      : String.fromCharCode(name.trim().runes.first).toUpperCase();
}

abstract class ProfileAccount implements Listenable {
  AccountProfile? get profile;
  String? get authError;
  Future<void> updateName(String name);
  Future<void> signIn();
  Future<void> signOut();
}
