# Growing Grounds — audit et nettoyage local

État : en cours, branche `codex/gg-quality-audit`, base `cd099f9`.
Périmètre autorisé : source Lua, outils Python, contrats réseau, configuration,
tests et documentation utile. Fin attendue : corrections et nettoyages locaux
commités, preuves et limites consignées ici. Aucun déploiement ni publication.

## Propriété et protections

- Ce checkout uniquement. Ni jeu, ni serveur, ni sauvegardes réelles manipulés.
- Le chat principal possède les runtimes et la présentation native.
- `codex/gg-palbox-totals` possède actuellement `range`, `runtime`, `settings`,
  `world_settings`, `texts`, `config` et leurs tests/docs. Lecture seule jusqu'à
  récupération de son commit stabilisé. Aucun sous-agent.
- Conserver autorité serveur, Pals occupés/verrouillés/ouverts, migrations,
  protocoles historiques, plafond automatique de 1 GiB, annulation sur relance,
  absence d'archivage en partie, publication atomique et restauration vérifiée.

## Liste courante

- [x] Lire instructions, contexte et STATUS partagé sans le modifier.
- [x] Vérifier checkout propre et établir les résultats de référence.
- [ ] Examiner tous les modules et leurs usages/tests/documentation.
- [ ] Corriger les défauts démontrés et simplifier les responsabilités dupliquées.
- [ ] Récupérer le changement stabilisé de croissance/réglages ; auditer ce résultat.
- [ ] Vérifier le résultat complet et les archives de distribution locales.
- [ ] Finaliser constats priorisés, suppressions justifiées et commits réversibles.

## Preuves

Référence `cd099f9` : 31 tests Python et 14 suites Lua × 2 interpréteurs
(5.5, 5.4) réussis. Commandes et journaux :
`.local/quality-audit/baseline.json`. Première invocation Lua invalide (argument
de racine omis), corrigée et conservée dans les journaux ; ce n'était pas un
échec produit.

## Constats et corrections

### P2 — baseline manquante masquée par une archive roulante

`tools/backup_policy.py:automatic_once` appliquait le délai et le contrôle
« unchanged » avant de vérifier la présence d'une baseline. Une copie roulante
seule empêchait donc la protection initiale, même après le délai. Sous Linux,
`baselines_before_first_launch` refuse alors le lancement. Une baseline corrompue
pouvait aussi être masquée par ces statuts. Correction : déterminer d'abord la
présence/l'intégrité de la baseline, puis réserver ces raccourcis aux rotations.
Le recul d'horloge reste bloquant ; aucune archive existante n'est remplacée.
Deux régressions, quatre cas en échec avant correction :
`.local/quality-audit/baseline-regression-before.log`.

### P2 — deux politiques de rétention appliquées à la même sauvegarde

L'appel automatique passait `keep=100` à `create`, puis appliquait sa propre
rétention. Une politique personnalisée `recent=101` perdait une copie de trop ;
ces suppressions intermédiaires disparaissaient aussi du résultat `removed`.
La régression échoue avant correction dans `.local/quality-audit/retention-before.log`.
`create(keep=None)` délègue maintenant la rétention à l'appelant automatique.
La rotation manuelle est isolée dans `rotate_rolling`, sans changer sa politique
par défaut. Cela élimine aussi un passage inutile de vérification des anciennes
archives à chaque rotation automatique. Aucun gain FPS revendiqué.

Suppression démontrée : import Python `timedelta` inutilisé dans `backup_policy`
(analyse AST des noms lus et inspection de tous les usages du module).

## Non vérifié

Validation native en jeu, persistance réelle des Pals, Windows physique,
Workshop installé, performances/FPS, compatibilité générale avec d'autres mods.
Les fixtures ne remplacent aucune de ces validations.
