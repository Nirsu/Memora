import 'package:flutter/material.dart';

class ObsGuideDialog extends StatelessWidget {
  const ObsGuideDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Prêt pour votre prochain meeting'),
    content: const SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Text(
          "1. Dans OBS, ajoutez une capture de fenêtre ou d'écran. Vérifiez que votre micro ET le son de l'appel font bouger les vumètres. Utilisez un casque.\n\n"
          "2. Enregistrez en MP4 hybride ou MKV avec une piste 1 contenant le mix complet. Faites un test de 30 secondes et réécoutez votre voix ainsi que le son de l'ordinateur.\n\n"
          "3. Préparez un meeting dans Memora et prenez vos notes. Le repère temps est manuel : lancez-le en même temps que l'enregistrement OBS.\n\n"
          "4. Après le meeting, arrêtez OBS, rattachez le fichier MP4 ou MKV dans Memora puis cliquez sur « Transcrire et résumer ».\n\n"
          "5. Relisez le résumé, corrigez les noms des passages et ajustez les captures. Cliquez sur un timestamp pour revoir la source.\n\n"
          "Cette version transcrit plusieurs voix, mais n'identifie pas automatiquement les intervenants. Les noms sont attribués manuellement. Les images sont proposées près des sujets importants, puis ajustables.",
          style: TextStyle(height: 1.7),
        ),
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("C'est compris"),
      ),
    ],
  );
}
