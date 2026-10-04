import 'package:flutter/material.dart';

import '../../theme.dart';

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // a sheet of the journal: a thin rule, and a gold mark at two of its corners
    return CustomPaint(
      foregroundPainter: _CornerMarks(AppColors.gold),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      ),
    );
  }
}

class _CornerMarks extends CustomPainter {
  const _CornerMarks(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 4.0;
    const arm = 10.0;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final top = Path()
      ..moveTo(inset, inset + arm)
      ..lineTo(inset, inset)
      ..lineTo(inset + arm, inset);
    final bottom = Path()
      ..moveTo(size.width - inset, size.height - inset - arm)
      ..lineTo(size.width - inset, size.height - inset)
      ..lineTo(size.width - inset - arm, size.height - inset);
    canvas.drawPath(top, paint);
    canvas.drawPath(bottom, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerMarks oldDelegate) => oldDelegate.color != color;
}

/// the card every list row and panel is built from, optionally tappable
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = AppRadius.card,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

/// the tab bar every tabbed screen uses
class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTabBar({super.key, required this.labels, this.scrollable = false});

  final List<String> labels;
  final bool scrollable;

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    // the plugin's tab strip: bright text on the picked tab over a short
    // gold underline, the rest dimmed, and a hairline under the whole row
    return TabBar(
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : null,
      labelColor: AppColors.text,
      unselectedLabelColor: AppColors.muted,
      dividerColor: AppColors.hairline,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.gold, width: 2.5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      tabs: [for (final label in labels) Tab(text: label)],
    );
  }
}

/// the small capitals over a card, like LIVE PREVIEW in the plugin
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: color ?? AppColors.textSoft),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = trailing;
    // a group title above its card, as the plugin's settings pages have them
    return Row(
      children: [
        Expanded(child: Text(title, style: display(16))),
        if (t != null) Text(t, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(value, style: display(21)),
      ],
    );
  }
}

class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: 6,
        backgroundColor: AppColors.track,
        color: color ?? AppColors.gold,
      ),
    );
  }
}

/// small pill used for chips and filters
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.background});

  final String text;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    // a coloured pill carries a faint rim of its own colour, as the plugin's do
    final tinted = color != null && color != AppColors.textSoft;
    final ink = color ?? AppColors.textSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: tinted ? ink.withValues(alpha: 0.12) : (background ?? AppColors.surface2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tinted ? ink.withValues(alpha: 0.4) : AppColors.line),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink)),
    );
  }
}

/// the title of a page with a line on what it is for, and a hairline under
/// both, as each page of the plugin's settings window opens
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: display(20)),
          if (sub != null) ...[
            const SizedBox(height: 5),
            Text(sub, style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted)),
          ],
          const SizedBox(height: 12),
          const Divider(),
        ],
      ),
    );
  }
}

/// a note with an accent bar down its left edge, the plugin's notice card
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.text, this.icon = Icons.info_outline, this.accentColor});

  final String text;
  final IconData icon;

  /// the amber of the palette when none is given
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.amber;
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: accent.withValues(alpha: 0.85)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 18, color: Color.lerp(accent, Colors.white, 0.2)),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSoft)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// the version in a small outlined pill, as beside the plugin's name
class VersionPill extends StatelessWidget {
  const VersionPill(this.version, {super.key});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(version, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSoft)),
    );
  }
}
