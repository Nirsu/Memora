import 'package:flutter/material.dart';

class EditTextDialog extends StatefulWidget {
  const EditTextDialog({
    super.key,
    required this.title,
    required this.initial,
    this.multiline = false,
  });
  final String title;
  final String initial;
  final bool multiline;

  @override
  State<EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<EditTextDialog> {
  late final controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 500,
      child: TextField(
        autofocus: true,
        controller: controller,
        minLines: widget.multiline ? 3 : 1,
        maxLines: widget.multiline ? 8 : 1,
        onSubmitted: widget.multiline
            ? null
            : (value) => Navigator.pop(context, value),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class ConfirmMeetingDialog extends StatelessWidget {
  const ConfirmMeetingDialog({
    super.key,
    required this.title,
    required this.message,
    required this.acceptLabel,
    this.destructive = false,
  });
  final String title;
  final String message;
  final String acceptLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: SizedBox(width: 420, child: Text(message)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: destructive ? const ValueKey('confirm-delete') : null,
        style: destructive
            ? FilledButton.styleFrom(
                backgroundColor: const Color(0xffb83b46),
                foregroundColor: Colors.white,
              )
            : null,
        onPressed: () => Navigator.pop(context, true),
        child: Text(acceptLabel),
      ),
    ],
  );
}

class AudioTrackDialog extends StatelessWidget {
  const AudioTrackDialog({super.key, required this.tracks});
  final List<Map<String, dynamic>> tracks;

  @override
  Widget build(BuildContext context) => SimpleDialog(
    title: const Text("Quelle piste contient tout l'appel ?"),
    children: [
      const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Choisissez le mix complet (micro + participants), généralement la piste 1 dans OBS. Une seule piste sera transcrite pour éviter les doublons.',
        ),
      ),
      for (final (index, track) in tracks.indexed)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, index),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              'Piste ${index + 1} · ${track['codec_name']} · ${track['channels']} canaux',
            ),
          ),
        ),
    ],
  );
}
