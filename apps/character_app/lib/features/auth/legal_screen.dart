import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';
import '../../theme/app_theme.dart';

/// Pages légales.
enum LegalPage { terms, privacy }

const _updated = 'Dernière mise à jour : 2 octobre 2026';

/// Conditions d'utilisation (`LegalTerms.dc.html`) et politique de
/// confidentialité (`LegalPrivacy.dc.html`), en lecture seule. Le texte
/// décrit ce que fait réellement l'app ; une adresse de contact sera ajoutée
/// avant la publication.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.page});

  final LegalPage page;

  @override
  Widget build(BuildContext context) {
    final (title, intro, sections, other, otherRoute) = switch (page) {
      LegalPage.terms => (
        "Conditions d'utilisation",
        'Ces conditions régissent l’utilisation de Grimoire pour créer, gérer '
            'et jouer des personnages de Donjons & Dragons (édition 2024). En '
            'utilisant l’app, tu acceptes les termes ci-dessous.',
        _terms,
        'Voir aussi la politique de confidentialité',
        AppRoutes.privacy,
      ),
      LegalPage.privacy => (
        'Politique de confidentialité',
        'Cette politique explique quelles données Grimoire enregistre, '
            'pourquoi, et comment tu peux les exporter ou les supprimer.',
        _privacy,
        "Voir aussi les conditions d'utilisation",
        AppRoutes.terms,
      ),
    };
    final theme = Theme.of(context);
    const paragraph = TextStyle(color: AppTheme.textMuted, height: 1.6);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(
              '$_updated · Lecture seule',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(intro, style: paragraph),
              for (final (heading, body) in sections) ...[
                const SizedBox(height: 18),
                Text(heading, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(body, style: paragraph),
              ],
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => context.pushReplacement(otherRoute),
                child: Text(other),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _terms = [
  (
    '1. Le service',
    'Grimoire permet de créer des personnages et de gérer leur fiche '
        '(caractéristiques, inventaire, sorts, bourse, notes). Le contenu de '
        'règles reprend le System Reference Document (SRD) 5.2.1 sous licence '
        'Creative Commons Attribution 4.0 ; il ne remplace pas les ouvrages '
        'officiels.',
  ),
  (
    '2. Ton compte',
    'Un compte anonyme est créé à ta première utilisation et rattaché à cet '
        'appareil. Tu peux le lier à une adresse e-mail (ou à Google sur le '
        'web) pour retrouver tes personnages ailleurs. Tu es responsable des '
        'actions faites depuis ton compte.',
  ),
  (
    '3. Ton contenu',
    'Les personnages, notes et textes que tu écris t’appartiennent. Le MJ '
        '(administrateur de l’app) peut consulter les fiches de personnage ; '
        'il ne voit jamais tes notes de session privées.',
  ),
  (
    '4. Ce que tu ne dois pas faire',
    'Utiliser le service pour publier du contenu illégal ou tenter d’en '
        'perturber le fonctionnement ou d’accéder aux données d’autres '
        'joueurs.',
  ),
  (
    '5. Disponibilité',
    'Grimoire est en version bêta : des fonctionnalités peuvent évoluer ou '
        'être momentanément indisponibles.',
  ),
  (
    '6. Résiliation',
    'Tu peux supprimer ton compte à tout moment depuis Réglages → Zone '
        'dangereuse. Tes personnages et tes notes sont alors effacés '
        'définitivement.',
  ),
];

const _privacy = [
  (
    '1. Données enregistrées',
    'Tes personnages (fiche, inventaire, sorts, bourse, personnalité), tes '
        'notes de session privées et, si tu lies ton compte, ton adresse '
        'e-mail ou ton identifiant Google. Aucune donnée de paiement.',
  ),
  (
    '2. Pourquoi',
    'Uniquement pour faire fonctionner l’app : afficher et synchroniser tes '
        'personnages. Les données sont hébergées par Google Firebase.',
  ),
  (
    '3. Qui voit quoi',
    'Toi seul·e modifies tes personnages. Le MJ (administrateur de l’app) '
        'peut lire les fiches de personnage, pas tes notes de session '
        'privées. Rien n’est partagé avec d’autres joueurs.',
  ),
  (
    '4. Conservation',
    'Tes données sont gardées tant que ton compte existe. Un compte anonyme '
        'non lié peut être perdu si tu effaces les données de l’app ou '
        'changes d’appareil.',
  ),
  (
    '5. Tes droits',
    'Depuis Réglages → Zone dangereuse, tu peux exporter une copie de tes '
        'données (personnages et notes, au format JSON) ou supprimer '
        'définitivement ton compte et tout son contenu.',
  ),
];
