# Direction UX/UI de Memora

Recherche et proposition du 7 septembre 2026. Cette étude prépare une refonte ; les écrans Flutter ne sont pas modifiés par cette proposition.

## Recommandation

Faire de Memora un carnet de réunion sombre, centré sur le contenu, avec deux usages très lisibles : **écrire pendant l’appel**, puis **relire avec les sources après l’appel**. Une bibliothèque compacte donne accès aux deux. Le résumé, la transcription, la vidéo et les captures doivent se répondre par leurs timestamps.

La direction combine la hiérarchie sobre de Linear, la souplesse des panneaux d’Obsidian et la relation texte–vidéo d’Octopus et tl;dv. Suite au retour utilisateur, la proposition lavande est abandonnée : la V2 part d’un noir neutre et de texte craie, avec deux variantes comparables, encre/sable et carbone/sauge. La référence à Codex est ici une préférence visuelle du projet, pas une analyse de ses fonctions.

## Révision V2 : couleurs et compte rendu adaptatif

Les deux captures fournies montrent des choix complémentaires : tl;dv organise les notes par sujets avec des timestamps ; Read AI sépare vue d’ensemble, actions et points de discussion, avec une colonne de moments sous la vidéo. Ces observations portent sur les captures uniquement. Elles ne permettent pas de savoir si les modèles de ces produits ont analysé visuellement les slides.

La V2 conserve un thème sombre. Un sélecteur permet de comparer trois palettes sur exactement le même contenu. Le compte rendu devient plus développé, avec des titres liés aux sujets du meeting ; la colonne vidéo contient les moments clés et l’extrait sélectionné. Tous les textes et timestamps de cette démonstration sont fictifs : ils ne résument pas les vidéos des captures utilisateur.

### Ce que fait le moteur aujourd’hui

Inspection de `ollama_client.dart`, `local_engine.dart` et `models/summary.dart` :

- Whisper transcrit l’audio ; Ollama reçoit les segments textuels, sans images de la vidéo.
- Le prompt demande 4 à 10 éléments courts par morceau. Au-delà de 18 éléments, une consolidation travaille par lots et demande au maximum 6 éléments par lot ; une boucle peut répéter cette réduction. Ce n’est pas un budget de détail adapté au contenu d’une réunion longue.
- Le rendu utilise quatre catégories fixes : À retenir, Décisions, Actions, Questions ouvertes. Les titres de chaque élément varient, et les catégories vides sont omises.
- Les images sont extraites près du début des segments cités, avec un plafond de 8 captures et des filtres de proximité/doublons. Elles illustrent le résumé après génération ; elles ne l’alimentent pas.

Le résumé actuel s’adapte donc au contenu parlé, mais sa structure et sa compression restent limitées. Il ne change pas de texte au fil de la lecture : ce sont le passage sélectionné et le lecteur qui doivent se synchroniser.

### Comportement cible

Une structure stable pour se repérer, un contenu variable pour représenter la réunion :

1. Vue d’ensemble, proportionnée au contenu et au niveau de détail choisi.
2. Sections thématiques générées à partir des échanges, sans plafond uniforme de trois points. Pour une réunion de mentorat : organisation des séances, rôle du mentor, accès aux outils, par exemple, uniquement si ces thèmes sont présents dans la source.
3. Décisions, actions, responsables et échéances quand ils sont explicitement mentionnés. Une formation sans tâches ne doit pas recevoir une liste d’actions inventées.
4. Questions ouvertes et désaccords lorsqu’ils existent ; références aux passages pour les informations principales.

Le choix « Court / Standard / Détaillé » contrôlerait le développement, tout en conservant les décisions et actions importantes. La durée seule ne suffit pas : une longue réunion répétitive peut être courte à résumer, une présentation dense peut nécessiter de nombreuses sections.

Cela exige une évolution du pipeline, pas uniquement un nouveau composant Markdown : extraire les sujets et faits sourcés par morceau, regrouper les doublons, conserver un inventaire des décisions/actions, puis rédiger par thème sans recondenser toute la réunion à une poignée d’éléments. Persister la structure et les IDs de sources avant le rendu Markdown, avec une migration qui conserve les résumés déjà édités.

Pour intégrer ce qui n’est visible que sur les slides, une étape distincte devra sélectionner des images pertinentes, extraire leur texte ou les décrire avec un modèle de vision local, puis citer ces sources visuelles. Les faits venant de l’écran devront être distingués des paroles. Rien de cette analyse visuelle n’est implémenté par la V2 de la maquette.

Validation à prévoir : comparer un point court, une formation et une réunion longue avec les mêmes critères de couverture ; vérifier les décisions, responsables et dates face aux sources, les références manquantes et les résultats des modes de détail. Ne pas annoncer une qualité comparable aux concurrents sans cette évaluation.

## Recherche et sélection

Les quatre pages Dribbble fournies ont été ouvertes, y compris la recherche générale. Les visuels complets de NoteWise, Meebuddy et Octopus ont été examinés dans le navigateur ; BrainJot a été sélectionné parmi les résultats puis observé. Les produits ci-dessous ont été étudiés à partir de leur documentation publique. Je n’ai pas effectué un test connecté de ces produits. Un concept Dribbble montre une composition, pas la preuve qu’une interaction fonctionne ni qu’elle convient à un usage prolongé.

| Référence | Observation | Adaptation proposée pour Memora | Ce que je ne reprendrais pas |
|---|---|---|---|
| [NoteWise — Heloxone](https://dribbble.com/shots/27334750-AI-Meeting-Note-SaaS-Landing-Page-NoteWise) | Landing page claire, grands titres éditoriaux, halos pastel et présentation en trois étapes. | Un premier lancement simple qui explique « Prendre des notes → Importer → Relire ». Quelques touches chaleureuses dans les états vides. | Les halos, perspectives de maquette et grands espaces marketing dans la bibliothèque quotidienne. Son thème clair ne correspond pas à la demande. |
| [Meebuddy — Cansaas](https://dribbble.com/shots/26586551-Meebuddy-AI-Note-Taking-Dashboard) | Titre global au-dessus du contenu ; vidéo principale, notes dessous, participants et actions à droite. | Titre et métadonnées communs à toute la réunion ; actions et timestamps proches du texte concerné. | La colonne permanente de participants/pièces jointes et les nombreuses entrées SaaS : elles occupent de la place pour des fonctions absentes de Memora. |
| [Octopus — Rama Zuldi](https://dribbble.com/shots/26415983-Octopus-AI-Note-Taking-Dashboard) | Résumé à gauche et vidéo à droite ; onglets et repères temporels sous le lecteur. | C’est la composition la plus proche du besoin de relecture : un document central, un lecteur toujours accessible et des moments sélectionnables. | Les statistiques de prise de parole, le coaching et les barres par personne : notre MVP ne dispose pas de diarisation fiable. |
| [BrainJot — Odama](https://dribbble.com/shots/26238598-BrainJot-AI-Note-Taking-Dashboard) | Liste de notes regroupée dans le temps ; vidéo et transcription simultanées. | Regrouper les réunions par date et permettre une vue « Vérifier » avec texte source et lecteur. | Les quatre colonnes simultanées. À une largeur Windows moyenne, elles laisseraient trop peu de place aux phrases et aux captures. |
| [Granola — notes enrichies](https://docs.granola.ai/help-center/taking-notes/ai-enhanced-notes) | Notes personnelles distinguées des notes enrichies ; possibilité de consulter l’origine d’un point du résumé. | Deux libellés explicites, « Mes notes » et « Résumé IA », et une action « Voir la source ». | Faire croire que nos notes guident déjà le résumé : actuellement, seul le transcript alimente notre pipeline. Ce serait une évolution fonctionnelle séparée. |
| [tl;dv — AI Meeting Notes](https://intercom.help/tldv/en/articles/7198123-ai-meeting-notes) et [notes horodatées](https://intercom.help/tldv/en/articles/5946332-manually-add-timestamped-notes-to-meetings) | Synthèses regroupées par thème, reliées à des instants de l’enregistrement ; repères manuels pendant ou après la réunion. | Timestamps visibles et cliquables ; capture, note et extrait doivent pointer vers le même moment. | Les bots et intégrations d’équipe ; OBS reste l’outil d’enregistrement de notre MVP. |
| [Linear — refonte de mars 2026](https://linear.app/now/behind-the-latest-design-refresh) | Barre latérale atténuée, commandes situées de façon cohérente, réduction du poids des icônes et séparateurs. | Réserver le contraste au document, à la sélection et à l’action principale. Même position pour titre, navigation et actions sur tous les écrans. | Une densité copiée au pixel près : lire un résumé demande davantage d’interligne qu’une liste de tickets. |
| [Obsidian — onglets et panneaux](https://obsidian.md/help/tabs) | Panneaux redimensionnables et dispositions conservées. | Un séparateur entre document et lecteur, une sidebar repliable, la largeur et le dernier onglet mémorisés. | Un système d’onglets arbitraires, de fenêtres et de plugins dès cette refonte. |
| [shadcn — sidebar](https://ui.shadcn.com/docs/components/base/sidebar) et [Resizable](https://ui.shadcn.com/preview/radix/resizable-example) | Composition régulière des zones de navigation et panneaux ajustables. | Reprendre la grammaire visuelle : boutons compacts, espaces cohérents, focus lisible, menus contextuels. | Ajouter une bibliothèque React au projet Flutter. Il s’agit d’une référence de design. |
| [Descript — visite produit](https://www.descript.com/tour) | Le texte joue un rôle central dans le travail sur un média. | Le transcript devient une surface de navigation, pas seulement un export consultable. | Le montage destructif de vidéo ou la timeline multipiste, hors du besoin de prise de notes. |

## Diagnostic de l’interface actuelle

Observations fondées sur `library_view.dart`, `meeting_view.dart`, `summary_pane.dart`, `replay_pane.dart`, `workspace_screen.dart` et le guide du MVP. Ce sont des constats d’interface et des hypothèses à valider à l’usage, pas des résultats de tests utilisateurs.

1. **La bibliothèque démarre trop bas.** Un grand slogan, son sous-titre, les boutons et un panneau OBS précèdent la liste. Remplacer cela, après le premier lancement, par un en-tête court, une recherche et les réunions récentes.
2. **Le replay reste petit.** La colonne est fixée à 360 pixels sur grand écran, et une grande carte de confidentialité occupe de la hauteur. Donner cette place au média et à ses sources ; déplacer les détails de stockage dans une fiche accessible depuis « Sur cet ordinateur ».
3. **La disposition change brusquement à 1 250 pixels.** Le replay passe d’une colonne à un onglet. Conserver une commande explicite « Afficher le lecteur » et la position de lecture ; le changement de largeur ne doit pas changer la tâche de l’utilisateur.
4. **Les captures arrivent après tout le résumé.** Elles sont faciles à manquer. Ajouter un onglet « Captures » avec vignettes et timestamps. Une association directe à un point du résumé doit être stockée explicitement ou qualifiée de simple proximité temporelle.
5. **La provenance demande des allers-retours.** Les liens déplacent le lecteur, mais le transcript n’indique pas automatiquement le passage courant. Mettre en évidence le segment source et proposer « Suivre la lecture », désactivable lorsque l’utilisateur parcourt ailleurs.
6. **L’état “Prêt” ne dit pas quoi faire.** Présenter « Notes seules », « À analyser », « Traitement en cours », « À relire », « Traitement interrompu ». “À relire” signifie contenu disponible, pas validation humaine ; “Relu” demanderait un nouvel état explicite.
7. **L’import, la régénération et la récupération demandent trop de connaissance préalable.** Donner une prochaine action selon le contexte. Une erreur doit dire ce qui est conservé et offrir une relance, pas seulement un message temporaire.

## Parcours proposés

### Bibliothèque

En-tête « Réunions » avec « Nouvelle réunion » et « Importer ». Recherche locale visible au-dessus de la liste. Commencer par le titre, comme aujourd’hui ; annoncer et implémenter séparément une future recherche dans les notes et transcriptions.

Liste par date, avec titre, durée et état. Un aperçu d’une ligne peut provenir du résumé, s’il existe. Pas de faux compteurs de temps gagné. Filtres « Toutes », « Notes seules », « À analyser », « À relire » basés sur les données réelles. Les réunions récentes suffisent dans la sidebar ; la bibliothèque contient la liste complète.

Le menu de ligne contient renommer, ouvrir les fichiers et supprimer. Une corbeille accessible rend la suppression réversible au-delà des dix secondes du toast actuel. Restaurer est une évolution fonctionnelle utile ; vider définitivement la corbeille est une action distincte avec confirmation et taille libérée.

### Pendant l’appel

Ouvrir directement « Mes notes » pour une réunion sans média. Le texte prend l’espace central ; masquer le lecteur vide. Garder titre éditable, sauvegarde locale et « Marquer un moment » visibles. Le message « OBS enregistre séparément » reste près du repère temps ; ne jamais afficher une pastille rouge “Enregistrement” sans capture réelle contrôlée par Memora.

« Importer l’enregistrement » rattache ensuite le fichier à ce même brouillon. Le repère temps actuel étant manuel, afficher ce caractère approximatif. Un offset réglable entre les marqueurs et l’enregistrement sera utile si les deux n’ont pas démarré ensemble, mais nécessite de structurer les marqueurs aujourd’hui stockés dans le texte.

### Import et traitement

Séquence courte : choisir le fichier → choisir le mix audio si nécessaire → lancer l’analyse. Expliquer que Memora copie le fichier et garde l’original. Le glisser-déposer peut compléter le sélecteur quand il sera réellement implémenté.

Progression par étapes : copie, préparation audio, transcription, résumé, captures. Afficher un pourcentage seulement si le moteur fournit une mesure fiable ; sinon, nom de l’étape et durée écoulée. Les notes et résultats disponibles restent consultables. La sortie « Annuler le traitement » conserve ces données. Après une erreur du résumé, offrir « Relancer le résumé » et laisser ouvrir la transcription.

### Après l’appel : relecture

Un titre et une petite ligne date/durée/état en haut. Au centre, onglets « Résumé », « Transcription », « Mes notes », « Captures ». À droite, lecteur ajustable ; cette zone contient vidéo/audio, commande de capture et extrait source courant. Le résumé est le choix par défaut lorsqu’il existe.

- Un point de résumé présente son texte et une référence temporelle. Cliquer révèle le passage exact et cale la vidéo ; l’utilisateur peut lancer la lecture. Le comportement doit être identique depuis résumé, transcript et capture.
- Les actions restent une section du résumé. Les transformer en cases à cocher persistantes demanderait un vrai modèle de tâches ; la première refonte n’affiche pas de cases trompeuses.
- Les noms sont indiqués comme attribués manuellement ; une voix inconnue reste « Intervenant non renseigné ». Ne pas inventer un nombre de participants en comptant les passages sans nom.
- Mode « Audio » : barre de lecture compacte, sans grand visuel d’onde fictif. Une vraie waveform n’est utile que si elle sert à naviguer et demanderait un calcul supplémentaire.
- « Capturer cette image » montre un retour avec miniature et timestamp. Chaque capture peut être agrandie, légendée et retirée. Une image proche dans le temps n’est pas présentée comme “validée par l’IA”.
- « Exporter » regroupe dossier Markdown + images, transcription et audio. Montrer le contenu produit. « Ouvrir les fichiers » est une action locale distincte.
- « Régénérer » est secondaire, dans le menu du résumé. Avant d’adopter une nouvelle version, montrer un aperçu et préserver les corrections, comme le stockage le permet déjà.

## Direction artistique

Proposition V2 **noir et craie** : fond `#171717`, navigation `#111111`, surfaces `#202020`, séparateurs `#343434`, texte `#EDEDEB`, texte secondaire `#ADADAA`, accent neutre `#E0E0DC`. Variantes : **encre et sable** (fond `#1C1A18`, accent `#D9BD91`) et **carbone et sauge** (fond `#171B19`, accent `#B1CBB5`). Chaque variante change aussi surfaces, sélection, séparateurs et textes pour conserver une palette cohérente. Couleurs de succès, d’attente et d’erreur accompagnées d’un texte. Ces valeurs sont des propositions, à contrôler sur les composants finaux et avec l’échelle Windows.

Police système Segoe UI : contenu de lecture 15–16 px, commandes 13–14 px, métadonnées 12–13 px ; titre d’écran 24–28 px. Interligne de lecture autour de 1,6. Échelle d’espacement 4/8/12/16/24/32 ; rayons de 6–10 px. Icônes de même famille et taille, sans carré décoratif autour de chacune. Boutons majeurs de hauteur 36–40 px. Une action dominante par état ; les boutons secondaires restent neutres.

Le document doit sembler posé dans l’application : pas de couches de cartes imbriquées, de transparence derrière les paragraphes ni de grandes zones lumineuses. Transitions brèves, aucune animation permanente. Garder focus clavier visible, labels des boutons importants, contrastes suffisants et états lisibles sans distinguer les couleurs.

### Deux variantes considérées

- **Carnet pur**, notes et résumé seuls au centre, lecteur ouvert à la demande : excellent pendant l’appel, moins adapté à la vérification régulière de l’écran partagé.
- **Studio de relecture**, lecteur et timeline dominants : utile pour revoir beaucoup de vidéo, mais trop lourd pour écrire quelques notes.

Retenir un **carnet avec lecteur contextuel**. Le prototype permet de comparer document large et lecteur large ; la sidebar peut être repliée. Ce sont des réglages de disposition du même produit, pas plusieurs identités graphiques à maintenir.

## Intégration dans Flutter

| Étape | Modifications | Dépendances fonctionnelles |
|---|---|---|
| 1 — Lisibilité et navigation | Tokens du thème, bibliothèque compacte, en-tête commun, actions contextuelles, suppression des grandes cartes d’explication, mode notes sans lecteur vide. | Réutilise les modèles et opérations actuels. Modifier les attentes textuelles des tests de widgets. |
| 2 — Relecture | Panneaux ajustables, onglet captures, agrandissement des images, mode audio compact, vitesse/volume du lecteur. | État de disposition et préférences persistantes ; commandes du lecteur à vérifier. |
| 3 — Sources | Segment courant, navigation source↔vidéo, suivi de lecture, association des captures aux points. | Persister les `SummaryItem` structurés et leurs IDs, aujourd’hui surtout rendus en Markdown ; préserver les liens après édition et gérer une source absente. Un timestamp seul ne recrée pas une relation fiable. |
| 4 — Parcours robustes | Statut par étape, erreurs persistantes, récupération des versions, corbeille visible et recherche étendue. | Données réelles de progression, aperçu de version, index local si nécessaire. Ne pas déduire un pourcentage à partir du numéro de l’étape. |

Garder les widgets déjà extraits : `LibraryView`, `MeetingHeader`, les quatre panneaux et les dialogues. Le view model conserve les actions métier ; l’état du lecteur et la sélection d’une source sont partagés au niveau du meeting. La proposition n’exige ni migration de framework ni nouvelle bibliothèque globale de gestion d’état.

## Critères de validation de la future implémentation

- À 1 440 × 900 et 1 024 × 768, les actions essentielles restent visibles et le texte lisible. À 900 pixels de largeur, un mode à un panneau préserve l’onglet, le brouillon et le temps de lecture. Vérifier aussi l’échelle Windows 125 % et 150 %.
- Une réunion sans média affiche immédiatement les notes ; aucun élément ne prétend enregistrer ou connaître les intervenants.
- Importer depuis un brouillon conserve ses notes et son identité, y compris après navigation pendant la copie.
- Cliquer trois sources différentes depuis le résumé, la transcription et les captures montre les bons timestamps et passages ; une source supprimée n’ouvre pas un autre passage par approximation silencieuse.
- Éditer puis régénérer ne détruit pas les corrections. Supprimer puis restaurer conserve médias, notes et résultats.
- Une erreur de moteur indique les résultats encore disponibles. Annuler libère le verrou ; on peut reprendre sans recréer le meeting.
- Le focus, la tabulation et les commandes clavier ne déclenchent pas le lecteur pendant la saisie. Tous les boutons importants sont accessibles sans survol.

## Portée du prototype

La proposition interactive utilise une réunion fictive, des notes d’exemple et un écran partagé dessiné pour illustrer la disposition. Navigation, sélection des sources, filtres et édition de démonstration sont locaux à l’aperçu. Elle n’enregistre rien, ne lit aucune vraie vidéo, ne lance pas de modèle et ne sauvegarde pas de meeting. Elle sert à discuter l’espace, la hiérarchie et les interactions avant leur implémentation Flutter.

Vérification de l’aperçu : rendu observé à 1 024, 736 et 360 pixels de largeur ; navigation résumé → source → transcription, capture → source, filtre « Notes seules », ouverture des notes, ajout d’un marqueur et accès à l’état de traitement exercés. Aucun avertissement ni erreur retourné par la console du navigateur. Ces contrôles concernent le prototype, pas une refonte déjà intégrée à l’application.

## Intégration réalisée — 7 septembre 2026

La direction noir et craie est intégrée dans Flutter : bibliothèque avec recherche, filtres et dates ; barre latérale compacte ; actions selon le contenu disponible ; notes sans lecteur vide. La relecture propose quatre onglets, un lecteur masquable et redimensionnable, un mode audio compact, le passage transcrit courant et les liens temporels du résumé. Les captures disposent d’une galerie, d’un agrandissement avec zoom et de leurs commandes de légende, retrait et replay. L’onglet et les éditeurs restent montés pendant les changements de disposition.

Les passages à revoir sont extraits des liens `memora://seek/…` déjà enregistrés dans le Markdown et des captures ; ils sont triés et dédupliqués. Cela ne remplace pas la conservation des relations structurées entre résumé et segments. Aucun contenu fictif ni nouvelle analyse visuelle n’est ajouté à l’application.

Restent à traiter séparément : résumé adaptatif et moins compressé, analyse du contenu des images, identification automatique des intervenants, association structurée des sources, réglages persistants de disposition et commandes de vitesse/volume. La génération locale existante est inchangée. Les propositions précédentes décrivent la direction complète, pas des fonctions toutes livrées dans cette première intégration.

Validation : analyse Dart sans avertissement, tests de non-régression (notes, suppression/restauration, exports), nouveau test de conservation de l’éditeur pendant les changements de largeur et test des repères temporels. Compilation Windows release et vérification native de la bibliothèque, du lien résumé → vidéo/transcription et de la galerie de captures sur une réunion simulée.
