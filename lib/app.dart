import 'dart:io';

import 'package:flutter/material.dart';

import 'services/local_files.dart';
import 'ui/core/app_theme.dart';
import 'ui/workspace_screen.dart';

class MemoraApp extends StatelessWidget {
  const MemoraApp({super.key, this.root});
  final Directory? root;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Memora',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    home: WorkspaceScreen(root: root ?? findProjectRoot()),
  );
}
