import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/app_theme.dart';
import '../characters/characters_providers.dart';
import 'auth_providers.dart';

/// Version affichée dans À propos (celle de `pubspec.yaml`).
const appVersion = '0.1.0';

/// Réglages (`Settings.dc.html`) : compte (lier la session anonyme, se
/// connecter, se déconnecter), à propos et pages légales, export des données
/// et suppression du compte. Tables et notifications viendront avec leurs
/// fonctionnalités.
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
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
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                isAnonymous
                    ? Icons.person_outline
                    : Icons.verified_user_outlined,
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
              onPressed:
                  _busy
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
              onPressed:
                  _busy
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
                onPressed:
                    _busy
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
              onPressed:
                  _busy
                      ? null
                      : () => _run(auth.signOut, success: 'Déconnecté.'),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
          ],
          const SizedBox(height: 24),
          _title(context, 'À propos'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text('Version'),
                  trailing: Text('$appVersion (bêta)'),
                ),
                ListTile(
                  title: const Text("Conditions d'utilisation"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.terms),
                ),
                ListTile(
                  title: const Text('Politique de confidentialité'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.privacy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _title(context, 'Zone dangereuse'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Exporter mes données'),
                  subtitle: const Text('Personnages et notes, au format JSON'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _export,
                ),
                ListTile(
                  textColor: Theme.of(context).colorScheme.error,
                  iconColor: Theme.of(context).colorScheme.error,
                  title: const Text('Supprimer mon compte'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _confirmDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
    ),
  );

  /// Export (`AccountExportData.dc.html`) : la copie s'affiche et se copie
  /// dans le presse-papiers, sans envoi par e-mail.
  Future<void> _export() async {
    final json = await ref.read(charactersControllerProvider).exportData();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Exporter mes données'),
            content: SizedBox(
              width: 560,
              height: 360,
              child: SingleChildScrollView(
                child: SelectableText(
                  json,
                  key: const Key('export-json'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: json));
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Copié dans le presse-papiers.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copier'),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    if (confirmed ?? false) {
      await _run(
        ref.read(charactersControllerProvider).deleteAccount,
        success: 'Compte supprimé.',
      );
    }
  }
}

/// Suppression du compte (`AccountDeleteConfirm.dc.html`) : ce qui sera
/// effacé, et « SUPPRIMER » à taper pour confirmer.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    final ok = _confirm.text.trim() == 'SUPPRIMER';
    return AlertDialog(
      title: const Text('Supprimer mon compte'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette action est irréversible. Seront définitivement '
                'supprimés, sur tous tes appareils :\n'
                '• tes personnages (fiches, inventaire, sorts, bourse) ;\n'
                '• tes notes de session privées ;\n'
                '• ton compte et ses connexions liées.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu peux exporter tes données avant de continuer.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('delete-confirm-field'),
                controller: _confirm,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Tape SUPPRIMER pour confirmer',
                  hintText: 'SUPPRIMER',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: error),
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: const Text('Supprimer définitivement'),
        ),
      ],
    );
  }
}
