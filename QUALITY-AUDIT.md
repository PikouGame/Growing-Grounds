# Growing Grounds — audit et nettoyage local

État : en cours, branche `codex/gg-quality-audit`, base `cd099f9`.
Périmètre autorisé : source Lua, outils Python, contrats réseau, configuration,
tests et documentation utile. Fin attendue : corrections et nettoyages locaux
commités, preuves et limites consignées ici. Aucun déploiement ni publication.

## Propriété et protections

- Ce checkout uniquement. Ni jeu, ni serveur, ni sauvegardes réelles manipulés.
- Le chat principal possède les runtimes et la présentation native.
- Changement stabilisé `38b162c` de `codex/gg-palbox-totals` récupéré sans conflit
  en `3c0a8a4` : gain indépendant par niveau et groupe près des réglages natifs.
  Son checkout reste intact. Aucun sous-agent.
- Conserver autorité serveur, Pals occupés/verrouillés/ouverts, migrations,
  protocoles historiques, plafond automatique de 1 GiB, annulation sur relance,
  absence d'archivage en partie, publication atomique et restauration vérifiée.

## Liste courante

- [x] Lire instructions, contexte et STATUS partagé sans le modifier.
- [x] Vérifier checkout propre et établir les résultats de référence.
- [ ] Examiner tous les modules et leurs usages/tests/documentation.
- [ ] Corriger les défauts démontrés et simplifier les responsabilités dupliquées.
- [x] Récupérer le changement stabilisé de croissance/réglages.
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

### P2 — ligne de récompense disparue mais encore comptée dans la hauteur

`src/ui.lua:UI.update` gardait la visibilité et la propriété d'une ligne retirée
par reconstruction native si son bonus venait aussi d'être désactivé. Au prochain
changement visible, `fitHeight` déréférençait cette ligne absente. Reproduit dans
`.local/quality-audit/ui-before.log`. Nettoyer la propriété de toute ligne absente
et sa contribution à la hauteur permet aussi sa recréation unique à la réactivation.
La suite UI passe sous Lua 5.5/5.4 : `ui-after-5.5.log`, `ui-after-5.4.log`.
Preuve par simulation du cycle des widgets, pas validation visuelle en jeu.

### P2 — réglages natifs tardifs et propriété des lignes reconstruites

`src/world_settings.lua:attach` ne marquait pas l'initialisation en attente
avant ses premiers retours. Une classe, un panneau ou un exemple natif absent
au premier appel empêchait donc toute reprise par `refresh`. Le drapeau est
maintenant posé avant ces vérifications, et le journal distingue l'attente.
Une ligne reconstruite invalide aussi le placement du groupe et libère l'ancien
slider : ses événements différés ne doivent plus modifier le brouillon actif.
Ce nettoyage est centralisé dans `forgetRow`, partagé avec la fermeture du menu.
Trois preuves d'échec conservées : `settings-before.log`,
`settings-placement-before.log`, `settings-ownership-before.log` sous
`.local/quality-audit/`. Suite de réglages réussie sous Lua 5.5/5.4 ; les tests
préservent identités, valeurs non enregistrées et ordre des contrôles natifs.

### Nettoyage sans changement de contrat joueur

- `Range.percent/radius` ne lisent plus le maximum de niveaux depuis le retour
  du gain indépendant. Retrait des paramètres formels et de leurs transmissions,
  ainsi que de la requête désormais inutile à `R.levels` dans le calcul des rayons.
  Les anciens arguments supplémentaires Lua restent acceptés ; les tests de
  tables 2/35/40/50 niveaux vérifient cette indépendance. Les coffres/Palbox
  continuent d'utiliser la table native pour leur répartition.
- `backup_windows.paths` : suppression du paramètre `mod` jamais lu ; les deux
  appels du dépôt ont été vérifiés et adaptés. Aucune interface CLI modifiée.
- `restore_copy` : suppression du `except BaseException: raise` sans effet.
  Le `finally` nettoie toujours le staging et une restauration interrompue reste
  marquée `RESTORE-INCOMPLETE.txt`. Un test protège ce résultat et les octets de
  l'archive initiale.
- Commentaires/messages des tests de migration corrigés : ils prétendaient
  encore que le gain était ignoré, alors que leurs assertions vérifiaient sa
  conservation. Aucune clé ancienne ni version réseau supprimée.

### Distribution — refactorisation et contrôles renforcés

`tools/release.py` exécutait tout l'assemblage dès son import. Les étapes sont
désormais séparées : `validate_sources`, `workshop_info`, `build_release` et
écriture d'une archive. Le CLI reste identique et l'import est sans écriture.
Les gardes explicites restent actifs avec `python -O`.

Risque latent corrigé, sans fichier manquant constaté dans le paquet courant :
l'ancien détecteur ne voyait ni les icônes construites via `spec.icon`, ni les
imports Python locaux. Les tests retirent volontairement un module Lua, un
module Python et l'icône Palbox de la liste autorisée et vérifient le refus.
La liste de distribution reste explicite ; aucun dossier de développement ajouté.

Trois tests de distribution réussis, aussi en mode optimisé. Le runtime officiel
déjà en cache dans le worktree de release a été copié en lecture seule vers ce
checkout, puis vérifié par son SHA-256 épinglé ; aucun téléchargement.
Les deux ZIP réels sont **identiques octet par octet avant/après refactorisation**
(SHA-256 et contenu vérifié), preuve `.local/quality-audit/release-equivalence.json`.
Les règles client/serveur Workshop sont conservées ; son installation reste non vérifiée.
Les archives restent des candidats privés nommés avec la version existante.

### P2 — sous-dossiers inconnus exclus du budget d'archives

`tools/backup_policy.py` comptait uniquement les fichiers immédiatement sous le
répertoire d'archives. Un sous-dossier contenant déjà le budget entier permettait
encore une nouvelle archive. Reproduit avec un budget réduit dans
`.local/quality-audit/nested-budget-before.log` (`created` au lieu de `storage-limit`).
Le décompte inclut maintenant toute l'arborescence, fichiers inconnus et partiels
compris, avec points d'annulation. Il ne suit pas les liens, y compris les cycles,
et ne supprime rien d'inconnu. Tests Python réussis après correction.

## Non vérifié

Validation native en jeu, persistance réelle des Pals, Windows physique,
Workshop installé, performances/FPS, compatibilité générale avec d'autres mods.
Les fixtures ne remplacent aucune de ces validations.
