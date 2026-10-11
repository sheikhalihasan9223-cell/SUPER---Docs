import 'profile_page.dart';
import 'package:flutter/material.dart';
import 'cloud_backend.dart';
import 'glass.dart';
import 'store.dart';

class AccountPanel extends StatefulWidget {
  final AppStore store;
  const AccountPanel({super.key, required this.store});
  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  bool busy = false;
  String? error;
  Future<void> accountAction(bool signOut) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final backend = SupabaseBackend.active;
      if (backend == null) {
        throw StateError('Google sign-in is not available in this build yet.');
      }
      if (signOut) {
        await backend.signOut();
      } else {
        await backend.signIn();
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (_, _) {
      final signedIn = widget.store.accountId != null;
      return GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_circle_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      signedIn ? 'Your account' : 'Keep your files with you',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                signedIn
                    ? SupabaseBackend.active?.email ?? 'Signed in'
                    : 'Sign in with Google to back up completed files and access them on your devices.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (signedIn) ...[
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(store: widget.store),
                    ),
                  ),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('View profile'),
                ),
                Text(
                  widget.store.syncing
                      ? 'Syncing files...'
                      : widget.store.syncError != null
                      ? 'Saved on this device. Cloud sync needs a retry.'
                      : 'Your private cloud workspace',
                  style: const TextStyle(fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: busy || widget.store.syncing
                      ? null
                      : widget.store.sync,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync files'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => accountAction(true),
                  child: const Text('Sign out'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: busy ? null : () => accountAction(false),
                  icon: const Icon(Icons.login),
                  label: const Text('Continue with Google'),
                ),
              if (busy) const LinearProgressIndicator(),
              if (error != null || SupabaseBackend.active?.authError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    error ?? SupabaseBackend.active!.authError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
