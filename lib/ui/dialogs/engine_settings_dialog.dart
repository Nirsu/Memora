import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../workspace_view_model.dart';

class EngineSettingsDialog extends StatelessWidget {
  const EngineSettingsDialog({super.key, required this.model});
  final WorkspaceViewModel model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => AlertDialog(
      title: const Text('Votre IA, sur votre ordinateur'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Text(
              model.engineIssues.isEmpty
                  ? 'Tous les moteurs sont prêts.'
                  : model.engineIssues.join('\n'),
              style: TextStyle(
                color: model.engineIssues.isEmpty
                    ? const Color(0xff8ad3b1)
                    : accent,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Transcription : Whisper large-v3-turbo\nRésumé : Qwen3 8B · Ollama local\nIntervenants : ${model.engine.hasDiarization ? 'détection locale installée' : 'installation facultative : scripts/setup-diarization.ps1'}\nCalcul après l'appel · aucun compte requis",
              style: const TextStyle(color: muted, height: 1.8),
            ),
            const SizedBox(height: 16),
            SelectableText(
              'Bibliothèque : ${model.repository.root.path}\n\nInstallation initiale : scripts/setup.ps1',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: model.checking || model.busy
              ? null
              : () => model.checkEngines(start: true),
          child: Text(
            model.checking ? 'Vérification…' : 'Démarrer et vérifier',
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}
