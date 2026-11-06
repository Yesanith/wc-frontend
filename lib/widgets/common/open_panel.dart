import 'package:flutter/material.dart';

import '../../theme.dart';

/// a page that is a screen of its own on a phone and a panel over the page where there is room, on a
/// computer, as the item sheet is: the page behind stays where it was
Future<void> openPanel(BuildContext context, WidgetBuilder builder) {
  final size = MediaQuery.sizeOf(context);
  if (size.width < 760) return Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  return showDialog<void>(
    context: context,
    builder: (dialog) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.window),
        side: BorderSide(color: AppColors.line),
      ),
      child: SizedBox(width: 680, height: (size.height - 48).clamp(320.0, 780.0), child: builder(dialog)),
    ),
  );
}
