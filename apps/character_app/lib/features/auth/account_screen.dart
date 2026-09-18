import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../characters/characters_providers.dart';
import 'auth_providers.dart';

/// Compte : lier la session anonyme, se connecter, se déconnecter, supprimer.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && success != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final auth = ref.watch(authServiceProvider);
    final isAnonymous = user?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                isAnonymous ? Icons.person_outline : Icons.verified_user_outlined,
              ),
              title: Text(user?.label ?? 'Connexion…'),
              subtitle: Text(
                isAnonymous
                    ? 'Tes persos sont sur cet appareil. Lie un e-mail pour '
                        'les retrouver sur le web et ne pas les perdre.'
                    : 'Tes persos se synchronisent sur tous tes appareils.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isAnonymous) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => auth.linkWithEmail(
                          _email.text.trim(),
                          _password.text,
                        ),
                        success: 'Compte lié : tes persos sont conservés.',
                      ),
              icon: const Icon(Icons.link),
              label: const Text('Lier ce compte'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => auth.signInWithEmail(
                          _email.text.trim(),
                          _password.text,
                        ),
                        success: 'Connecté.',
                      ),
              child: const Text('Déjà un compte ? Se connecter'),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                          auth.linkWithGoogle,
                          success: 'Compte Google lié.',
                        ),
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continuer avec Google'),
              ),
            ],
          ] else ...[
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        await auth.signOut();
                        await auth.ensureSignedIn();
                      }, success: 'Déconnecté.'),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
          ],
          const SizedBox(height: 32),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _busy ? null : _confirmDelete,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Supprimer mon compte et mes personnages'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: const Text(
          'Tous tes personnages seront effacés sur tous tes appareils. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _run(
        ref.read(charactersControllerProvider).deleteAccount,
        success: 'Compte supprimé.',
      );
    }
  }
}
