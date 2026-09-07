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

## Review : corrections et limites

L'ancien `main.dart` mélangeait près de 1 950 lignes d'interface, de dialogues et d'actions. Il ne contient plus que le démarrage. Le stockage et la communication Ollama sont également séparés du traitement des médias. Vider le résumé pendant son édition ne fait désormais plus disparaître le champ de saisie.

Le modèle `Meeting` reste un agrégat mutable : la transcription, les captures et les notes sont mises à jour progressivement. Une migration complète vers des objets immuables nécessiterait de revoir ce flux ; elle n'est pas simulée par un simple découpage de fichiers. Le traitement média reste regroupé dans `LocalEngine`, car ses étapes partagent l'annulation et la gestion des processus. Une seule opération lourde s'exécute à la fois. Si plusieurs réunions doivent être traitées en parallèle, il faudra isoler cet état par tâche.

Les panneaux dépendent de données et de callbacks, mais l'écran de composition connaît encore le view model et les dialogues natifs. Les tests utilisent un dépôt temporaire et les moteurs locaux pour le test de bout en bout ; ils ne prouvent pas la qualité du résumé d'une réunion longue ni la diarisation, qui reste absente.

## Références

Les choix suivent les recommandations officielles de [séparation des responsabilités Flutter](https://docs.flutter.dev/app-architecture/recommendations) et d'[extraction en widgets](https://docs.flutter.dev/perf/best-practices). Les syntaxes utilisées sont documentées dans [Dart : enhanced enums](https://dart.dev/language/enums) et [Dart : dot shorthands](https://dart.dev/language/dot-shorthands). Le projet demande Dart `^3.13.1` dans `pubspec.yaml`.
