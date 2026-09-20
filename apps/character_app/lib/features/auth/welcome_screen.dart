import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'auth_providers.dart';
import 'auth_service.dart';

/// Premier écran, tant qu'aucune session n'est ouverte (cf. `_AuthGate`).
/// Reprend la maquette `Login.dc.html` / `LoginWeb.dc.html` : une colonne
/// sur mobile, un panneau de marque à côté du formulaire à partir de 600px.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  var _busy = false;
  var _showEmailForm = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
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
    final auth = ref.read(authServiceProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final content =
        _showEmailForm
            ? _EmailAuthForm(
              auth: auth,
              onBack: () => setState(() => _showEmailForm = false),
            )
            : _WelcomeContent(
              busy: _busy,
              onStart: () => _run(auth.ensureSignedIn),
              onGoogle: kIsWeb ? () => _run(auth.signInWithGoogle) : null,
              onEmail: () => setState(() => _showEmailForm = true),
            );

    final scaffold =
        !isWide
            ? Scaffold(
              body: SafeArea(
                child: Center(child: SingleChildScrollView(child: content)),
              ),
            )
            : Scaffold(
              body: Row(
                children: [
                  Expanded(
                    flex: 11,
                    child: ColoredBox(
                      color: AppTheme.surface,
                      child: const Center(
                        child: SingleChildScrollView(child: _BrandPanel()),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 9,
                    child: Center(child: SingleChildScrollView(child: content)),
                  ),
                ],
              ),
            );

    // Le retour système doit revenir à Bienvenue depuis le formulaire
    // e-mail, jamais quitter l'app : ce sous-arbre n'a pas de route
    // parente vers laquelle "revenir" (cf. `_WelcomeNavigator`).
    return PopScope<void>(
      canPop: !_showEmailForm,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _showEmailForm = false);
      },
      child: scaffold,
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Emblem(size: 96, iconSize: 46),
          const SizedBox(height: 22),
          Text('[Nom de l\'app]', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Compatible SRD 5.2', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Text(
            'Gère tes personnages D&D 2024 hors-ligne, à la table — '
            'création guidée, fiche vivante, montée de niveau sans erreur.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.size, required this.iconSize});

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.accent,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(
        Icons.shield_outlined,
        size: iconSize,
        color: AppTheme.background,
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({
    required this.busy,
    required this.onStart,
    required this.onGoogle,
    required this.onEmail,
  });

  final bool busy;
  final VoidCallback onStart;
  final VoidCallback? onGoogle;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Emblem(size: 64, iconSize: 30),
            const SizedBox(height: 14),
            Text('[Nom de l\'app]', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Compatible SRD 5.2', style: theme.textTheme.bodySmall),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onStart,
                child: const Text('Commencer à jouer'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aucun compte requis pour commencer',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider(color: AppTheme.border)),
                Flexible(
                  // Le texte doit garder la quasi-totalité de la place :
                  // les séparateurs n'ont besoin que d'un filet de largeur.
                  flex: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ou connecte-toi',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: AppTheme.border)),
              ],
            ),
            const SizedBox(height: 20),
            if (onGoogle != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onGoogle,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Continuer avec Google'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onEmail,
                icon: const Icon(Icons.mail_outline),
                label: const Text('Continuer avec e-mail'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Un compte anonyme sera créé quand tu commenceras à jouer. '
              'Relie-le à Google ou à un e-mail depuis les réglages pour '
              'retrouver tes personnages sur un autre appareil.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulaire e-mail, affiché en place plutôt qu'en dialogue (plus simple
/// que pousser une route sur `_WelcomeNavigator` pour un seul écran).
/// Créer un compte (anonyme + liaison) ou se connecter à un compte
/// existant : voir `AuthService.linkWithEmail`/`signInWithEmail`.
class _EmailAuthForm extends StatefulWidget {
  const _EmailAuthForm({required this.auth, required this.onBack});

  final AuthService auth;
  final VoidCallback onBack;

  @override
  State<_EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends State<_EmailAuthForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    // Capturé avant le premier await : réussir `ensureSignedIn()` fait
    // basculer `_AuthGate` vers l'app et démonte ce widget avant que
    // `linkWithEmail` échoue — `context` ne serait alors plus valide.
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Exception catch (e) {
      // Le SnackBar (messager capté au-dessus de `_AuthGate`) est la seule
      // garantie fiable : le texte inline peut être écrasé dès la frame
      // suivante si `ensureSignedIn()` a déjà réussi entre-temps.
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: _busy ? null : widget.onBack,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Retour',
            ),
            Text('Continuer avec e-mail', style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
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
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _busy
                        ? null
                        : () => _run(() async {
                          await widget.auth.ensureSignedIn();
                          await widget.auth.linkWithEmail(
                            _email.text.trim(),
                            _password.text,
                          );
                        }),
                child: const Text('Créer un compte'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    _busy
                        ? null
                        : () => _run(
                          () => widget.auth.signInWithEmail(
                            _email.text.trim(),
                            _password.text,
                          ),
                        ),
                child: const Text('Déjà un compte ? Se connecter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
