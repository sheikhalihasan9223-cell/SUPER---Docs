import 'package:flutter/material.dart';
import 'cloud_backend.dart';
import 'profile_model.dart';
import 'glass.dart';
import 'models.dart';
import 'store.dart';

class ProfilePage extends StatefulWidget {
  final AppStore store;
  final ProfileAccount? account;
  const ProfilePage({super.key, required this.store, this.account});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool busy = false;
  String? message;
  ProfileAccount? get account => widget.account ?? SupabaseBackend.active;
  late final Listenable changes = Listenable.merge([widget.store, account]);
  Future<void> action(Future<void> Function() run, {String? success}) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await run();
      if (mounted) setState(() => message = success);
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editName(AccountProfile profile) async {
    final controller = TextEditingController(text: profile.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // The dialog's exit animation still uses its text controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (!mounted || result == null) return;
    if (result.isEmpty) {
      setState(() => message = 'Please enter your name.');
      return;
    }
    await action(
      () => account!.updateName(result),
      success: 'Profile updated.',
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: changes,
    builder: (_, _) {
      final profile = account?.profile;
      final files = widget.store.accountId == profile?.id
          ? widget.store.files
          : <DocFile>[];
      return Scaffold(
        appBar: const GlassAppBar(title: Text('Profile')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: brandPurple.withValues(alpha: .12),
                          child: profile?.photoUrl == null
                              ? profile == null
                                    ? ClipOval(
                                        child: Image.asset(
                                          'assets/branding/super_docs_symbol.png',
                                          width: 92,
                                          height: 92,
                                        ),
                                      )
                                    : Text(
                                        profile.initial,
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          color: brandPurple,
                                        ),
                                      )
                              : ClipOval(
                                  child: Image.network(
                                    profile!.photoUrl!,
                                    width: 92,
                                    height: 92,
                                    fit: BoxFit.cover,
                                    cacheWidth: 184,
                                    errorBuilder: (_, _, _) => Text(
                                      profile.initial,
                                      style: const TextStyle(
                                        fontSize: 32,
                                        color: brandPurple,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          profile?.name ?? 'Your workspace, wherever you go.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile?.email ??
                              'Sign in to keep your files backed up and available on your devices.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (profile != null) ...[
                          const Chip(
                            avatar: Icon(Icons.check_circle_outline, size: 18),
                            label: Text('Google account'),
                          ),
                          TextButton.icon(
                            onPressed: busy ? null : () => editName(profile),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit profile'),
                          ),
                        ] else
                          FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () => action(() async {
                                    if (account == null) {
                                      throw StateError(
                                        'Google sign-in is not available in this build yet.',
                                      );
                                    }
                                    await account!.signIn();
                                  }),
                            icon: const Icon(Icons.login),
                            label: const Text('Continue with Google'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Dark mode'),
                    subtitle: const Text('Use a darker appearance'),
                    value: widget.store.dark,
                    onChanged: busy
                        ? null
                        : (value) =>
                              action(() => widget.store.settings(dark: value)),
                  ),
                ),
                if (profile != null) ...[
                  const SizedBox(height: 18),
                  GlassCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.folder_outlined,
                            color: brandPurple,
                          ),
                          title: const Text('My files'),
                          subtitle: Text('${files.length} saved files'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, 'files'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.cloud_done_outlined,
                            color: brandPurple,
                          ),
                          title: const Text('Private cloud backup'),
                          subtitle: Text(
                            widget.store.syncing
                                ? 'Syncing your files...'
                                : widget.store.syncError != null
                                ? 'Some files need a sync retry. Device copies are kept.'
                                : 'Completed files back up automatically',
                          ),
                          trailing: IconButton(
                            tooltip: 'Sync files',
                            onPressed: busy || widget.store.syncing
                                ? null
                                : widget.store.sync,
                            icon: const Icon(Icons.sync),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.lock_outline,
                            color: brandPurple,
                          ),
                          title: const Text('Only you can access your files'),
                          subtitle: const Text(
                            'Your documents are private to your account.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => action(() => account!.signOut()),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: LinearProgressIndicator(),
                  ),
                if (message != null || account?.authError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      message ?? account!.authError!,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
