import 'package:flutter/material.dart';

import '../../theme.dart';

/// a titled card of rows split by hairlines, the plugin's settings group
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, this.caption, required this.children});

  final String title;
  final String? caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cap = caption;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: display(16)),
          if (cap != null) ...[
            const SizedBox(height: 4),
            Text(cap, style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
          ],
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(indent: 14, endIndent: 14),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// one row of a [SettingsGroup]: a label, an optional note under it and a
/// control on the right
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.label, this.note, this.trailing, this.onTap});

  final String label;
  final String? note;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final n = note;
    final end = trailing;
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSoft)),
                if (n != null) Text(n, style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.muted)),
              ],
            ),
          ),
          if (end != null) ...[const SizedBox(width: 12), end],
        ],
      ),
    );
    return onTap == null ? body : InkWell(onTap: onTap, child: body);
  }
}
