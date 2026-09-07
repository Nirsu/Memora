import 'package:flutter/material.dart';

import 'app_theme.dart';

class NavigationItem extends StatelessWidget {
  const NavigationItem({
    super.key,
    required this.icon,
    required this.title,
    required this.active,
    required this.action,
    required this.compact,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback action;
  final bool compact;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Material(
    color: active ? selectedSurface : Colors.transparent,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        child: Row(
          children: [
            Tooltip(
              message: title,
              child: Icon(icon, size: 20, color: active ? accent : muted),
            ),
            if (!compact) ...[
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? ink : muted,
                        fontWeight: .w600,
                      ),
                    ),
                    if (subtitle case final subtitle?)
                      Text(
                        subtitle,
                        style: const TextStyle(color: muted, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
