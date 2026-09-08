# Organisation du code

La refonte sépare l'interface, l'état applicatif, le stockage et les moteurs locaux. `main.dart` initialise Flutter et le lecteur ; `app.dart` configure l'application. Les dépendances sont passées par constructeur, sans nouvelle dépendance de gestion d'état.

## Où modifier quoi

| Besoin | Fichier ou dossier |
|---|---|
| Composition de l'espace de travail, sélecteurs de fichiers, cycle de vie du lecteur | `lib/ui/workspace_screen.dart` |
| Actions utilisateur, sélection, sauvegarde, verrou des opérations et notifications | `lib/ui/workspace_view_model.dart` |
| Accueil et barre latérale | `lib/ui/library/` |
| Composition et en-tête d'un meeting | `lib/ui/meeting/meeting_view.dart`, `meeting_header.dart` |
| Résumé, transcription, notes ou replay | Les widgets `*_pane.dart` dans `lib/ui/meeting/` |
| Dialogues et réglages des moteurs | `lib/ui/dialogs/` |
| Thème et petits composants partagés | `lib/ui/core/` |
| Données et conversion JSON | `lib/models/` |
| Sauvegardes ordonnées, récupération et corbeille | `lib/data/meeting_repository.dart` |
| Import, FFmpeg, Whisper, captures et exports | `lib/services/local_engine.dart` |
| Requêtes HTTP locales, lancement et arrêt d'Ollama | `lib/services/ollama_client.dart` |
| Parties du résumé et curseur des captures sauvegardés | `lib/services/summary_checkpoint.dart` |
| Comparaison conservatrice de miniatures en niveaux de gris | `lib/utils/frame_similarity.dart` |
| Parsing des tours de voix et attribution aux passages | `lib/models/speaker_turn.dart` |
| Groupes de voix, réglage du nombre et correction individuelle | `lib/ui/meeting/speakers_panel.dart`, `lib/ui/dialogs/speaker_dialog.dart` |
| Racine de l'application et ouverture d'Explorer | `lib/services/local_files.dart` |

## Conventions retenues

- Les panneaux sont de vrais `StatelessWidget` ou `StatefulWidget`, avec données et callbacks explicites. Les mutations persistantes passent par le view model. Pas de fichiers `part` pour masquer un état monolithique.
- `WorkspaceViewModel` utilise `ChangeNotifier`. Son état est exposé par des getters et ses collections par des listes non modifiables. Les panneaux conservent leur état visuel : recherche de transcription, édition du résumé, minuteur des notes, mode audio seul. Le minuteur ne reconstruit plus tout l'espace de travail.
- Les contrôleurs de texte et abonnements sont libérés par leur propriétaire. Le dialogue d'édition possède son contrôleur ; il n'a plus besoin d'un délai arbitraire avant destruction.
- Les enhanced enums `MeetingStatus`, `SummaryKind` et `SaveState` réunissent les valeurs et leurs libellés. `MeetingStatus` porte aussi `isProcessing` : les traitements en cours ne sont plus reconnus par comparaison de textes français.
- Les dot shorthands sont utilisées quand le type attendu est évident (`.start`, `.w600`, `.ready`). Les patterns valident la forme des éléments JSON ; les records de `.indexed` fournissent les index des pistes audio.
- `SummaryItem` remplace les maps dynamiques manipulées après validation du résumé. Ses champs et références aux segments sont immuables. Le JSON des outils externes est validé ou converti à l'entrée.
- `flutter_lints` reste la base, avec `strict-casts`, `strict-inference` et `unawaited_futures`. Utiliser `dart format lib test scripts`, `flutter analyze` et `flutter test` avant de livrer une modification.

## Compatibilité des réunions

La lecture accepte les anciens statuts français et les nouveaux codes d'enum. Charger une réunion ne réécrit pas son fichier. À la prochaine sauvegarde, le JSON passe en version 2 et stocke le code du statut ; les autres données restent conservées. Les réunions interrompues pendant une phase de traitement sont présentées comme interrompues au redémarrage.

L'identifiant d'un meeting est validé à sa création et doit correspondre au nom de son dossier au chargement. Une incohérence déclenche la lecture de la sauvegarde précédente ; elle ne doit jamais rediriger une future écriture vers un autre meeting.

## Limites de l'architecture

Le modèle `Meeting` reste un agrégat mutable : la transcription, les captures et les notes sont mises à jour progressivement. Une migration complète vers des objets immuables nécessiterait de revoir ce flux ; elle n'est pas simulée par un simple découpage de fichiers. Le traitement média reste regroupé dans `LocalEngine`, car ses étapes partagent l'annulation et la gestion des processus. Une seule opération lourde s'exécute à la fois. Si plusieurs réunions doivent être traitées en parallèle, il faudra isoler cet état par tâche.

Les panneaux dépendent de données et de callbacks, mais l'écran de composition connaît encore le view model et les dialogues natifs. Les tests utilisent un dépôt temporaire et les moteurs locaux pour le test de bout en bout ; ils ne prouvent pas la qualité du résumé d'une réunion longue ni l'exactitude des attributions de voix.

## Intervenants locaux

`LocalEngine` appelle le CLI Windows sherpa-onnx sur le WAV 16 kHz mono. `speaker_turn.dart` convertit ses temps en millisecondes. Un passage est attribué au groupe ayant le plus de recouvrement uniquement s'il couvre au moins 50 % du passage et 70 % du recouvrement vocal total. Ces seuils détectent une ambiguïté temporelle, pas une confiance acoustique. Aucun mot n'est artificiellement déplacé ou scindé à partir de timestamps indisponibles.

`Segment.speakerId` référence `Meeting.speakerNames`. `Meeting.speakerLabel` résout le nom pour l'interface, les prompts et les exports. Le champ historique `speaker` reste une correction manuelle prioritaire ; `speakerLocked` conserve les corrections individuelles lors d'une nouvelle détection. Les nouveaux champs ont des valeurs par défaut pour les réunions existantes. La clé du cache du résumé contient également les noms de groupes.

La détection fait partie du traitement après Whisper mais reste facultative : une erreur est enregistrée dans `speakerError` sans bloquer le résumé. Le bouton dédié réutilise l'audio disponible et préserve le texte et le résumé. `diarization.txt` conserve les tours bruts ; `diarization.log` conserve la sortie du moteur. Une nouvelle détection sauvegarde les groupes précédents avant leur remplacement. Aucun enregistrement vocal permanent entre réunions n'est créé.

## Traitement récupérable

- L’extraction écrit `audio.partial.wav`, puis renomme ce fichier seulement après succès. `audioExtracted` permet de réutiliser cette sortie après interruption ; les anciens meetings sans ce champ restent lisibles.
- `summary.checkpoint.json` sauvegarde chaque partie validée et le prochain repère visuel à traiter. La clé contient la version des consignes, le nom du modèle et la transcription avec ses identifiants, horodatages et corrections. Les changements invalident les parties précédentes. Les fichiers de travail sont publiés par écriture temporaire puis renommage.
- La synthèse travaille directement depuis les passages originaux, avec un budget de 18 000 caractères par partie. La réduction récursive et la limite globale de 18 éléments sont supprimées ; seuls les doublons textuels exacts sont retirés. Les rubriques vides sont omises et chaque référence validée reçoit son lien temporel. Les longues réunions peuvent encore présenter des répétitions entre parties.
- Les consignes distinguent discussion, décision explicite, engagement futur et question ouverte. Qwen3 utilise son mode de raisonnement. Le schéma JSON limite les références aux identifiants fournis, et une génération tronquée est signalée comme erreur. Cela vérifie la forme et l’existence des sources, pas la véracité de chaque reformulation.
- Les captures proches sont comparées sur des miniatures 64 × 36 en niveaux de gris avec des seuils conservateurs. La limite de huit captures automatiques est conservée. Cette comparaison ne comprend pas les slides et ne garantit pas la pertinence d’une image.

## Références techniques supplémentaires

Le format structuré suit [la documentation Ollama](https://docs.ollama.com/capabilities/structured-outputs). Le test de replay utilise [le même lecteur media_kit](https://pub.dev/documentation/media_kit/latest/media_kit/MediaKit/ensureInitialized.html) que l’application.

Les choix suivent les recommandations officielles de [séparation des responsabilités Flutter](https://docs.flutter.dev/app-architecture/recommendations) et d'[extraction en widgets](https://docs.flutter.dev/perf/best-practices). Les syntaxes utilisées sont documentées dans [Dart : enhanced enums](https://dart.dev/language/enums) et [Dart : dot shorthands](https://dart.dev/language/dot-shorthands). Le projet demande Dart `^3.13.1` dans `pubspec.yaml`.
