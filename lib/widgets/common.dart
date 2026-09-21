import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/gw2_api.dart';
import '../state/api.dart';
import '../state/settings.dart';
import '../theme.dart';

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

/// the card every list row and panel is built from, optionally tappable
/// pull to refresh helper: drop the cached values and keep the spinner
/// visible long enough to feel deliberate
Future<void> refreshProviders(WidgetRef ref, List<ProviderOrFamily> providers) async {
  for (final provider in providers) {
    ref.invalidate(provider);
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = 14,
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
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

/// icon, title, optional subtitle and trailing widget. the shape of almost
/// every list in the app
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    this.icon,
    this.rarity,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconSize = 40,
    this.titleLines = 2,
  });

  final String? icon;
  final String? rarity;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double iconSize;
  final int titleLines;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    final end = trailing;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ItemIcon(url: icon, rarity: rarity, size: iconSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: titleLines,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                if (sub != null)
                  Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          if (end != null) ...[const SizedBox(width: 8), end],
        ],
      ),
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
    return TabBar(
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : null,
      labelColor: AppColors.gold,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.gold,
      dividerColor: AppColors.track,
      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      tabs: [for (final label in labels) Tab(text: label)],
    );
  }
}

/// the diamond emblem, drawn on the start screen and the hero card
class DiamondEmblem extends StatelessWidget {
  const DiamondEmblem({super.key, required this.size, this.color = AppColors.gold, this.filled = true});

  final double size;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _EmblemPainter(color, filled)),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  const _EmblemPainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size > 90 ? 2 : 1.6;
    final cx = size.width / 2;
    final cy = size.height / 2;

    Path diamond(double r) => Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();

    canvas.drawPath(diamond(size.width / 2 - 2), stroke);
    canvas.drawPath(diamond(size.width / 2 - size.width * 0.22), stroke);
    if (filled) {
      canvas.drawPath(diamond(size.width * 0.1), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}

class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color = AppColors.gold});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: color),
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
    return Row(
      children: [
        Expanded(child: Text(title, style: display(18))),
        if (t != null)
          Text(t, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 14)),
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
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class ErrorBox extends ConsumerWidget {
  const ErrorBox({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retry = onRetry;
    final s = ref.watch(stringsProvider);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: const TextStyle(color: AppColors.textSoft, fontSize: 14)),
              ),
            ],
          ),
          if (retry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: retry, child: Text(s.t('retry'))),
          ],
        ],
      ),
    );
  }
}

/// loading, error and data in one place. when [permission] is set, a 401 or
/// 403 is reported as a missing api key permission instead of an error
class AsyncView<T> extends ConsumerWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.permission,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final String? permission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return value.when(
      data: builder,
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        final needed = permission;
        if (needed != null && e is Gw2ApiException && (e.status == 401 || e.status == 403)) {
          return Panel(
            child: Text(s.t('needs_permission', {'p': needed}),
                style: const TextStyle(color: AppColors.muted, height: 1.5)),
          );
        }
        return ErrorBox(message: '$e', onRetry: onRetry);
      },
    );
  }
}

class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.color = AppColors.gold});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: 6,
        backgroundColor: AppColors.track,
        color: color,
      ),
    );
  }
}

class ItemIcon extends StatelessWidget {
  const ItemIcon({super.key, this.url, this.rarity, this.size, this.count, this.empty = false});

  final String? url;
  final String? rarity;
  final double? size;
  final int? count;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final u = url;
    final n = count;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: empty ? AppColors.navBg : AppColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: empty ? AppColors.track : rarityColor(rarity), width: 1.5),
      ),
      child: empty
          ? null
          : Stack(
              fit: StackFit.expand,
              children: [
                if (u != null)
                  Image.network(
                    u,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                  ),
                if (n != null && n > 1)
                  Positioned(
                    right: 3,
                    bottom: 1,
                    child: Text(
                      '$n',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

Future<void> openUrl(BuildContext context, String url, {String failMessage = 'Could not open the page'}) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failMessage)));
  }
}

/// opens a wiki page in the in-app browser, using the wiki that matches the app language
Future<void> openWikiPage(BuildContext context, WidgetRef ref, String title) {
  final wiki = ref.read(wikiApiProvider);
  final s = ref.read(stringsProvider);
  return openUrl(context, wiki.pageUrl(title), failMessage: s.t('open_failed'));
}

/// small pill used for chips and filters
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AppColors.textSoft, this.background = AppColors.surface2});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
