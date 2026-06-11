import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

BoxDecoration mutedPanelDecoration(ShadThemeData theme) {
  return BoxDecoration(
    color: theme.colorScheme.muted,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: theme.colorScheme.border),
  );
}
