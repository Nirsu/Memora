import 'package:flutter/material.dart';

import '../../models/meeting.dart';

class DeleteMeetingButton extends StatelessWidget {
  const DeleteMeetingButton({super.key, required this.meeting, this.onDelete});
  final Meeting meeting;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('delete-${meeting.id}'),
    tooltip: onDelete == null ? 'Traitement en cours' : 'Supprimer le meeting',
    onPressed: onDelete,
    icon: const Icon(Icons.delete_outline_rounded, size: 18),
  );
}
