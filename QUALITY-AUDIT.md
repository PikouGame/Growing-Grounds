# Growing Grounds — audit et nettoyage local

État : terminé localement le 12 novembre 2026, branche `codex/gg-quality-audit`,
base `cd099f9` puis intégration de `38b162c`.
Périmètre autorisé : source Lua, outils Python, contrats réseau, configuration,
tests et documentation utile. Corrections et nettoyages locaux committés ; preuves
et limites consignées ici. Aucun déploiement ni publication.

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

Centralisation des réglages — approuvée explicitement :
- [x] Partager les définitions canoniques entre calcul, persistance et sliders.
- [x] Conserver migrations, valeurs, ordre/format des fichiers et contrôles natifs.
- [x] Comparer au code précédent, exécuter les suites pertinentes et committer.
Le fichier utilisateur `config.lua` reste explicite et éditable ; sa concordance
avec les valeurs par défaut canoniques est vérifiée par les tests.

Les cinq définitions résident dans `src/range.lua`, sans nouveau module ni
dépendance. `Range.settingFields()` fournit des copies des noms, valeurs par
défaut, minima, références aux maxima/pas existants, clés de traduction et formats
d'affichage/enregistrement. Le calcul lit les mêmes défauts/minima ; `settings`
en déduit la liste de lecture/écriture ; `world_settings` en déduit ses sliders.
Les copies empêchent un consommateur de modifier les défauts internes. Les
formats réseau et valeurs de migration historiques restent indépendants : leur
signification ne doit pas suivre un futur changement de défaut. Les valeurs
fractionnaires autorisées dans la configuration restent fractionnaires.

Preuves : `.local/quality-audit/settings-schema/receipt.json`. Sous Lua 5.5 et
5.4, comparaison avec le code de `4564d81` : **17 537 cas de normalisation et
progression**, incluant toutes les paires Palbox 1..96, tous les couples entiers
gain/plafond et des valeurs invalides/historiques ; **2 002 cycles de persistance
et relecture identiques octet par octet**. Les deux sources antérieures et le
comparateur sont conservés dans ce dossier de preuves. Les 15 suites Lua passent
sous les deux versions ; les trois tests Python de distribution et l'assemblage
réel des archives passent. Les nouvelles assertions permanentes vérifient la
concordance de `config.lua`, les clés des 17 cultures, l'isolation des métadonnées
et un format enregistré exact. Aucun réglage utilisateur, sauvegarde réelle,
contrôle natif ou placement de logo modifié. Validation native de cette révision
non effectuée ; rien n'attend PK pour terminer cette refactorisation locale.

Suivi après audit — scénarios automatisés approuvés :
- [x] Reprendre le checkout et conserver les ajouts stabilisés du logo natif
  (`451fcf0`, `0d2a249`) sans intervenir sur le runtime.
- [x] Relier réglages, calcul serveur, réplication simulée et vraies récompenses UI.
- [x] Tester l'annulation aux étapes sensibles de publication des archives.
- [x] Vérifier et committer les tests locaux ; conserver la validation native
  au chat principal. Les autres propositions restent des idées à préciser.

Les ajouts de logo stabilisés du chat principal sont conservés en `0c3a5dd` et
`4d95b27`. Ils ont été intégrés sans conflit, sans installation ni retouche.
Les nouveaux scénarios ajoutent uniquement des tests et un mode de réutilisation
des doubles de widgets existants ; aucune logique de gameplay n'a été modifiée.

Preuves du suivi : `.local/quality-audit/flows/receipt.json`.
**43 tests Python et 15 suites Lua × 5.5/5.4 réussis**, contrôles de distribution
en mode optimisé et assemblage réel réussis. Le nouveau parcours relie les vrais
modules `settings`, `range`, `runtime`, `preview` et `ui`. Il vérifie 24 ordres
de réception (niveau, rayon, position et échelle du composant), un changement de
politique persisté/relu, la réouverture pendant une mise à jour incomplète,
le changement de langue, l'absence de réécriture au repos et le reset serveur.
Un contrôle négatif dans une copie jetable force un mauvais prochain pourcentage
dans le décodeur : le nouveau test échoue comme attendu (`negative-control.log`).
La réception UE4SS et les objets/widgets natifs restent simulés.

Les tests d'annulation injectent `Cancelled` au contrôle de l'inventaire source,
pendant l'écriture du ZIP, pendant sa vérification et avant son renommage final.
Chaque cas conserve les octets des archives précédentes, retire le partiel et
libère le verrou. Une interruption après publication laisse une nouvelle archive
complète dont la restauration est vérifiée, sans supprimer les précédentes.
Ces injections complètent le test existant d'annulation coopérative pendant
l'écriture ; elles ne reproduisent pas une coupure électrique ou une relance
native Windows/Linux. Aucun nouveau défaut produit démontré par ces scénarios.

Pour la suite native, PK interviendra uniquement sur les manipulations du jeu
préparées par le chat principal : ouverture/fermeture du menu, observation des
capacités, puis vérification des Pals après rechargement du monde d'essai.
Aucune intervention de PK n'est nécessaire pour cette étape automatisée.

- [x] Lire instructions, contexte et STATUS partagé sans le modifier.
- [x] Vérifier checkout propre et établir les résultats de référence.
- [x] Examiner tous les modules et leurs usages/tests/documentation.
- [x] Corriger les défauts démontrés et simplifier les responsabilités dupliquées.
- [x] Récupérer le changement stabilisé de croissance/réglages.
- [x] Vérifier le résultat complet et les archives de distribution locales.
- [x] Finaliser constats priorisés, suppressions justifiées et commits réversibles.

Prochaine étape hors de cet audit : le chat principal peut intégrer les commits
locaux puis organiser sa validation native. Rien n'attend une réponse de PK pour
terminer ce périmètre. Le runtime actuellement installé n'a pas été changé ici.

## Preuves

Référence `cd099f9` : 31 tests Python et 14 suites Lua × 2 interpréteurs
(5.5, 5.4) réussis. Commandes et journaux :
`.local/quality-audit/baseline.json`. Première invocation Lua invalide (argument
de racine omis), corrigée et conservée dans les journaux ; ce n'était pas un
échec produit.

Résultat de l'audit initial sur `91717a6`, consigné dans `c2c05a4` :
**41 tests Python**, **14 suites Lua sous 5.5.1 et 5.4.9**, compilation des 21
fichiers Lua sous les deux versions, trois tests de distribution sous Python
optimisé, assemblage réel des deux ZIP et `git diff --check` réussis.
Python exécuté : 3.14.9. Les outils passent aussi l'analyse syntaxique 3.9 ;
ce n'est pas une exécution sur Python 3.9.

Reçu détaillé : `.local/quality-audit/final.json` (commandes, statuts, versions,
SHA-256 des sources/tests/docs et manifeste final). Il pointe vers les journaux
bruts conservés dans le même répertoire. Le paquet manuel compte 83 fichiers,
le paquet Workshop 85, sans les tests ni ce suivi. Les empreintes finales sont
distinctes de la preuve d'équivalence de la seule refactorisation de release :
les corrections ultérieures de budget et documentation changent le contenu.

## Couverture et invariants conservés

- `Scripts/main`, `objects`, `changes` : chargement, gardes, hooks UE4SS,
  coalescence, timers sur le thread du jeu, caches et repli quand une notification
  n'est pas disponible. Les hooks dynamiques et signatures de callbacks restent.
- `range`, `runtime`, `config`, `settings` : autorité serveur, distances de
  placement, partage de l'espace entre bases, gain/cap indépendants, migration
  des clés historiques, brouillons et récupération après échec de renommage.
- `storage`, `palbox` : origine des dimensions, croissance bornée, références
  natives et réplication, rétention des Pals occupés/verrouillés/ouverts, reset
  et traitement distinct d'une expansion externe. Leurs mécanismes de durée de
  vie restent distincts : réplication dédiée pour les Pals, échange de slots
  d'objets lors d'un reset de coffre. Les fusionner aurait masqué ces différences.
- `preview` : formats historiques et total-cap, champs bornés/exacts en float,
  arrivée séparée des champs, rotation de révision, données exclusivement
  serveur. Les anciens caps/maximums et branches de décodage ne sont pas du
  code mort ; les tests couvrent leur lecture. Aucun protocole modifié.
- `ui`, `chest_ui`, `world_settings`, `language`, `texts` : reconstruction,
  activation, propriété des lignes, dimensions, langues et repli anglais.
  Vérification mécanique des 17 cultures ; pas de certification linguistique.
- `motion`, `boundary`, `ring`, `ribbon`, `wave` : préparation bornée, fermeture
  du menu, ordre vague/rebond/contour, nettoyage et absence de nouvelles traces
  pendant le balayage visible. Les constantes visuelles sont intentionnelles.
- Tous les outils Python : archive/restore, politique, annulation, sessions
  Linux et Windows, appels Win32, setup, runtime embarqué et distribution.
  Les lectures répétées de la source avant publication vérifient la cohérence
  des sauvegardes ; elles sont conservées. Seule la rotation automatique
  redondante a été retirée. Les fixtures natives manuelles sont des points
  d'entrée utiles, pas des scripts morts.
- README, INSTALL, BACKUPS, configuration et début du changelog vérifiés contre
  le code courant. Listings/visuels historiques laissés au chantier design.

## Priorité de revue

Les défauts démontrés ci-dessous sont P2 : budget/baseline/rétention en premier,
puis cycles de widgets et instructions de migration. Tous sont corrigés ici.
L'assemblage avait des lacunes de garde, sans paquet incomplet constaté ; elles
sont distinguées des bugs reproduits. Aucun P0/P1 démontré par cet audit local.

## Constats et corrections

### P2 — baseline manquante masquée par une archive roulante

`tools/backup_policy.py:85` (`automatic_once`) appliquait le délai et le contrôle
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
La rotation manuelle est isolée dans `tools/save_backup.py:186` (`rotate_rolling`), sans changer sa politique
par défaut. Cela élimine aussi un passage inutile de vérification des anciennes
archives à chaque rotation automatique. Aucun gain FPS revendiqué.

Suppression démontrée : import Python `timedelta` inutilisé dans `backup_policy`
(analyse AST des noms lus et inspection de tous les usages du module).

### P2 — ligne de récompense disparue mais encore comptée dans la hauteur

`src/ui.lua:264` et `:307` gardaient la visibilité et la propriété d'une ligne retirée
par reconstruction native si son bonus venait aussi d'être désactivé. Au prochain
changement visible, `fitHeight` déréférençait cette ligne absente. Reproduit dans
`.local/quality-audit/ui-before.log`. Nettoyer la propriété de toute ligne absente
et sa contribution à la hauteur permet aussi sa recréation unique à la réactivation.
La suite UI passe sous Lua 5.5/5.4 : `ui-after-5.5.log`, `ui-after-5.4.log`.
Preuve par simulation du cycle des widgets, pas validation visuelle en jeu.

### P2 — réglages natifs tardifs et propriété des lignes reconstruites

`src/world_settings.lua:86` (`attach`) ne marquait pas l'initialisation en attente
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

`tools/release.py:59` et `:101` : le module exécutait tout l'assemblage dès son import. Les étapes sont
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

`tools/backup_policy.py:70` : le décompte ne couvrait que les fichiers immédiatement sous le
répertoire d'archives. Un sous-dossier contenant déjà le budget entier permettait
encore une nouvelle archive. Reproduit avec un budget réduit dans
`.local/quality-audit/nested-budget-before.log` (`created` au lieu de `storage-limit`).
Le décompte inclut maintenant toute l'arborescence, fichiers inconnus et partiels
compris, avec points d'annulation. Il ne suit pas les liens, y compris les cycles,
et ne supprime rien d'inconnu. Tests Python réussis après correction.

### P2 — instructions actuelles encore contradictoires sur le gain

`README.md:89` et `INSTALL.txt:21` affirmaient encore qu'un ancien `growthPercentPerLevel` était
ignoré et que la croissance suivait obligatoirement le nombre de niveaux. Le
code stabilisé fait l'inverse. Les instructions actuelles sont corrigées, et la
section historique de la version publiée est explicitement identifiée. Son texte
historique, les listings publics et les visuels du chantier design restent intacts.

## Non vérifié

**Non vérifié / Not verified** : validation native en jeu de cette branche,
persistance réelle des Pals, focus/manette/reconstruction UMG natifs, Windows
physique et jonctions réelles Windows, relance réelle systemd/Win32 sur cette
révision, Workshop installé, exécution Python 3.9, performances/FPS et
compatibilité générale avec d'autres mods. Les fixtures de processus et de
réplication ne remplacent aucune de ces validations. Aucun nouveau défaut de
perte de Pals n'a été reproduit ; cela ne constitue pas une preuve de sauvegarde
native. Les checks en jeu et la présentation restent au chat principal.
