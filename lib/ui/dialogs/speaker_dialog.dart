import 'package:flutter/material.dart';

import '../../models/meeting.dart';

typedef SpeakerAssignment = ({String speakerId, String name});

class SpeakerDialog extends StatefulWidget {
  const SpeakerDialog({
    super.key,
    required this.meeting,
    required this.segment,
  });
  final Meeting meeting;
  final Segment segment;
  @override
  State<SpeakerDialog> createState() => _SpeakerDialogState();
}

class _SpeakerDialogState extends State<SpeakerDialog> {
  late String speakerId =
      widget.segment.speaker.isEmpty &&
          widget.meeting.speakerNames.containsKey(widget.segment.speakerId)
      ? widget.segment.speakerId
      : '';
  late final name = TextEditingController(text: widget.segment.speaker);
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Intervenant de ce passage'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: speakerId,
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Autre nom / non attribué'),
              ),
              for (final voice in widget.meeting.speakerNames.entries)
                DropdownMenuItem(value: voice.key, child: Text(voice.value)),
            ],
            onChanged: (value) => setState(() => speakerId = value ?? ''),
            decoration: const InputDecoration(labelText: 'Voix'),
          ),
          if (speakerId.isEmpty) ...[
            const SizedBox(height: 16),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Nom facultatif, pour ce passage',
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Cette correction concerne uniquement ce passage. Pour nommer tous les passages d’une voix, utilisez sa fiche dans la transcription.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop<SpeakerAssignment>(context, (
          speakerId: speakerId,
          name: speakerId.isEmpty ? name.text.trim() : '',
        )),
        child: const Text('Appliquer'),
      ),
    ],
  );
}
