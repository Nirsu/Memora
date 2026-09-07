# Review du MVP — 7 septembre 2026

La review porte sur le code Flutter, le stockage, le traitement local et les parcours actuels. Les corrections ci-dessous sont incluses dans le code ; la vérification ne constitue pas une garantie pour tous les formats ni pour une réunion longue.

## Défauts corrigés

| Priorité | Défaut observé dans le code | Correction |
|---|---|---|
| P1 | Un nouvel export réutilisait le même dossier et pouvait écraser une version corrigée à la main. | Un dossier distinct est créé à chaque export, avec suffixe si nécessaire. |
| P2 | Les chemins transmis à Explorer mélangeaient les séparateurs Windows et Unix. Le bouton pouvait ouvrir Documents. | Chemin absolu existant, résolu et converti en chemin Windows ; même fonction pour le dossier du meeting et celui de l'export. Un dossier absent produit une erreur. |
| P2 | L'ajout manuel d'une capture et l'export ne verrouillaient pas le traitement ; la suppression pouvait déplacer leurs fichiers pendant leur utilisation. | Capture, import, export et traitement IA partagent le verrou de l'interface. La suppression est désactivée tant qu'une opération l'utilise. |
| P2 | L'import prenait le meeting sélectionné après l'analyse du fichier, et pouvait rattacher un fichier à un autre brouillon après navigation. | Le brouillon cible est retenu dès le lancement ; le verrou couvre aussi la lecture des pistes. |
| P2 | Annuler une copie attendait la fin du transfert complet avant de réagir. | Vérification de l'annulation entre les blocs du fichier et nettoyage de la copie partielle. |
| P2 | Le repère temps se réinitialisait en quittant la vue du meeting. | Un départ propre à chaque meeting reste disponible pendant la session. |
| P2 | Un lien Markdown incomplet tel que `memora://seek` provoquait une erreur en accédant à un segment absent. | Seuls les liens avec un timestamp entier positif ou nul sont acceptés. |
| P2 | Le script de validation ajoutait ses réunions fictives dans la bibliothèque utilisateur. | Bibliothèque de test isolée dans `.local/smoke/`. |

Le bouton **Ouvrir le dossier du meeting** donne accès à la copie de l'enregistrement, au fichier `meeting.json` (notes, résumé, transcription et intervenants), aux captures et aux journaux disponibles. Le résumé portable destiné au partage se crée avec **Exporter**.

## Vérifications

- `flutter analyze` : aucune anomalie.
- Compilation Windows Release réussie et application relancée. Clic sur **Ouvrir le dossier du meeting** dans la version corrigée : une fenêtre Explorer portant l'identifiant attendu du meeting a été ouverte. L'inspection détaillée de cette fenêtre n'a pas été effectuée, l'autorisation de l'outil Explorer ayant expiré.
- `flutter test` : 9 tests, notamment annulation d'import sans altérer l'original, chemins Explorer avec espaces/accents et dossier absent, sauvegardes ordonnées, copie de secours, suppression/restauration, conservation des médias et noms d'intervenants, liens invalides, export distinct et navigation avec le repère temps.
- Le test d'interface couvre la création, les notes, un marqueur, l'annulation du dialogue de suppression, la suppression puis la restauration, à 1440 × 900 et 900 × 720.
- Parcours complet effectué sur un MP4 fictif d'environ 59 secondes : import, Whisper local, Qwen3 local, 10 segments, 3 captures automatiques, puis 1 capture manuelle. Environ 9 secondes sur cet essai avec moteurs disponibles. Pas une estimation pour une réunion longue.
- Export Markdown/JSON et audio M4A vérifiés. ffprobe confirme une seule piste audio et aucune vidéo dans le M4A.
- Annulation d'un processus FFmpeg réel, puis nouvelle commande réussie.
- Les tests synthétiques n'ont pas modifié les réunions utilisateur.

### Vérification après la refonte Flutter/Dart

- `flutter analyze` : aucune anomalie avec les contrôles de typage renforcés ; `flutter test` : 13 tests réussis.
- Nouveaux tests : lecture des anciens statuts et absence de réécriture au chargement, exclusion des opérations concurrentes et libération du verrou après erreur, sauvegarde via le view model, maintien de l'éditeur lorsque le résumé est vidé et aperçu après correction.
- Le même MP4 d'essai a été retraité avec Whisper et Qwen3 après la séparation des services : 10 segments, 2 captures automatiques retenues après filtrage des doublons, puis 1 capture manuelle, en environ 9 secondes. Exports et annulation FFmpeg vérifiés à nouveau dans la bibliothèque isolée.
- Compilation Windows Release réussie. Dans l'application recompilée : bibliothèque existante, résumé, transcription, notes, chargement vidéo et saut depuis un timestamp suivis d'une pause vérifiés visuellement sur le meeting simulé.
- Le détail du découpage, des conventions et des limites techniques figure dans [l'architecture](architecture.md).

## Périmètre et limites actuelles

| Fonction | État |
|---|---|
| Notes, renommage, recherche, suppression et annulation | Disponibles ; persistance et parcours couverts par les tests cités. |
| Import vidéo/audio | Disponible ; MKV et MP4 exercés. OBS reste responsable de la capture et de la présence des voix. Les autres extensions proposées n'ont pas toutes un test média dédié. |
| Pistes audio multiples | Choix manuel du mix complet ; une seule piste est transcrite pour éviter les doublons. |
| Transcription | Whisper local, langue française fixée ; la précision sur les chevauchements et noms propres reste à évaluer. |
| Intervenants | Attribution manuelle par passage, pas de diarisation automatique. |
| Résumé | Génération locale avec références aux segments ; ces références n'assurent pas à elles seules la fidélité du texte. Relecture nécessaire. |
| Régénération | Le résumé éditable est conservé ; le menu permet d'adopter le dernier résumé généré et garde la version précédente. |
| Captures | Automatiques près des passages sélectionnés, ajout/retrait et légende manuels. Pas de compréhension de l'écran ; seuls les doublons strictement identiques sont filtrés. |
| Replay / audio seul | Lecteur et timestamps disponibles ; audio seul masque l'image. Export M4A séparé. |
| Notes dans la synthèse IA | Non : elles sont sauvegardées et incluses dans l'export, mais pas transmises au modèle. |
| Corbeille | Conservation locale et annulation pendant 10 secondes. Pas encore de vue pour restaurer ou vider la corbeille ; elle continue d'occuper du disque. |
| Repère temps | Manuel et conservé pendant la navigation ; non persistant après fermeture de l'app. |
| Reprise | Réutilise une transcription déjà sauvegardée ; une transcription interrompue repart du début. |
| Packaging | Version personnelle liée au dossier du projet et à `.runtime` ; pas d'installeur autonome. |

Les performances et la qualité d'une réunion d'une heure, les coupures réseau physiques et l'annulation durant chaque phase de chargement des modèles n'ont pas été validées. La voix synthétique anglaise de la vidéo d'essai prononce du français : elle permet de vérifier la chaîne technique, pas de mesurer la qualité linguistique.

## Nettoyage du dépôt

- Guide et review regroupés dans `docs/`, README et configuration Flutter simplifiés ; suppression des commentaires de template sans rôle dans l'application.
- Ancien plan et configuration IDE générée retirés de la racine et conservés dans `.local/repo-archive`, ignoré par Git. La suppression définitive avait été refusée par le contrôle automatique.
- Sources Windows, métadonnées Flutter, verrou de dépendances, tests et scripts conservés : ils servent à reconstruire et vérifier l'application.
- `.local/`, `.runtime/`, `build/` et `.dart_tool/` restent ignorés par Git. Les modèles, les réunions et la version compilée nécessaire au lanceur n'ont pas été supprimés.
