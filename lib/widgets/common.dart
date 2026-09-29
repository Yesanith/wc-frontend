import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/gw2_api.dart';
import '../l10n/strings.dart';
import '../services/icon_cache.dart';
import '../state/api.dart';
import '../state/navigation.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../screens/onboarding_screen.dart';
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
        borderRadius: BorderRadius.circular(AppRadius.card),
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
  // without this the cached copy would come straight back
  ref.read(gw2ApiProvider).forceNetwork();
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
                if (sub != null) Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
    // the plugin's tab strip: bright text on the picked tab over a short
    // gold underline, the rest dimmed, and a hairline under the whole row
    return TabBar(
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : null,
      labelColor: AppColors.text,
      unselectedLabelColor: AppColors.muted,
      dividerColor: AppColors.hairline,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.gold, width: 2.5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
      ..strokeWidth = size.width > 90 ? 2 : 1.6;
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

/// the small capitals over a card, like LIVE PREVIEW in the plugin
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color = AppColors.textSoft});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: color),
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
        if (t != null)
          Text(t, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13)),
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
        Text(value, style: display(21)),
      ],
    );
  }
}

/// crafting disciplines come from the api in english, translate the known ones
const _disciplines = {
  'Armorsmith',
  'Artificer',
  'Chef',
  'Huntsman',
  'Jeweler',
  'Leatherworker',
  'Scribe',
  'Tailor',
  'Weaponsmith',
  'Homesteader',
};

String disciplineLabel(S s, String discipline) =>
    _disciplines.contains(discipline) ? s.t('disc_${discipline.toLowerCase()}') : discipline;

/// a failure in plain words. the api's own text stays as a small detail
/// for anything that is not simply "no connection"
String friendlyError(S s, Object? error) {
  if (error is Gw2ApiException) {
    return switch (error.kind) {
      ApiErrorKind.offline => s.t('err_offline'),
      ApiErrorKind.timeout => s.t('err_timeout'),
      ApiErrorKind.unauthorized => s.t('err_unauthorized'),
      ApiErrorKind.notFound => s.t('err_not_found'),
      ApiErrorKind.rateLimited => s.t('err_rate_limited'),
      ApiErrorKind.server => s.t('err_server'),
      ApiErrorKind.noKey => s.t('err_no_key'),
      ApiErrorKind.other => s.t('err_generic'),
    };
  }
  if (error is TimeoutException) return s.t('err_timeout');
  return s.t('err_generic');
}

/// the welcome screen as a page of its own, where a key is entered. it closes
/// itself once the key is saved
void openAddKey(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()));
}

class ErrorBox extends ConsumerWidget {
  const ErrorBox({super.key, this.message, this.error, this.onRetry});

  /// a ready message, used as is
  final String? message;

  /// or the error itself, turned into a friendly message
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retry = onRetry;
    final s = ref.watch(stringsProvider);
    final e = error;
    final text = message ?? friendlyError(s, e);
    // the raw text helps with reports, but not for the obvious cases
    final needsKey = e is Gw2ApiException && e.kind == ApiErrorKind.noKey;
    final quiet =
        needsKey || (e is Gw2ApiException && (e.kind == ApiErrorKind.offline || e.kind == ApiErrorKind.timeout));
    final detail = message == null && e != null && !quiet ? '$e' : null;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: const TextStyle(color: AppColors.textSoft, fontSize: 14)),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(detail,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.hint, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (needsKey) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: () => openAddKey(context), child: Text(s.t('add_api_key'))),
          ] else if (retry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: retry, child: Text(s.t('retry'))),
          ],
        ],
      ),
    );
  }
}

/// loading, error and data in one place. when [permission] is set, a 401 or
/// 403 is reported as a missing api key permission instead of an error, but
/// only when the key really is missing it. [restricted] is shown instead when
/// the key has the permission and the server still refused
class AsyncView<T> extends ConsumerWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.permission,
    this.restricted,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final String? permission;

  /// why the account itself may not read this, for endpoints the api limits
  /// beyond the key's permissions
  final String? restricted;

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
          // the api also answers 403 when the key is fine but the account is
          // not allowed to read this, so check the key before blaming it
          final granted = ref.watch(tokenInfoProvider).valueOrNull?['permissions'];
          final hasPermission = granted is List && granted.map((p) => '$p').contains(needed);
          final note = hasPermission ? restricted : s.t('needs_permission', {'p': needed});
          if (note != null) {
            return Panel(
              child: Text(note, style: const TextStyle(color: AppColors.muted, height: 1.5)),
            );
          }
        }
        return ErrorBox(error: e, onRetry: onRetry);
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
      borderRadius: BorderRadius.circular(999),
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
    final fixed = size;
    if (fixed != null) return SizedBox.square(dimension: fixed, child: _framed(fixed));
    // in a grid the cell decides the size
    return LayoutBuilder(builder: (context, box) {
      final side = box.biggest.shortestSide.isFinite ? box.biggest.shortestSide : 44.0;
      return _framed(side);
    });
  }

  Widget _framed(double side) {
    final u = url;
    final n = count;
    // rounder corners on bigger icons, a frame drawn over the art so the
    // image never covers the rarity colour
    final radius = BorderRadius.circular(side * 0.22);
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: empty ? AppColors.track : (rarity == null ? AppColors.line : rarityColor(rarity)),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: ColoredBox(
              color: empty ? AppColors.navBg : AppColors.surface2,
              child: empty || u == null ? const SizedBox.expand() : CachedIcon(url: u),
            ),
          ),
        ),
        if (!empty && n != null && n > 1)
          Positioned(
            right: 3,
            bottom: 1,
            child: Text(
              n > 9999 ? '${n ~/ 1000}k' : '$n',
              style: TextStyle(
                fontSize: (side * 0.26).clamp(9, 14).toDouble(),
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 3), Shadow(blurRadius: 1)],
              ),
            ),
          ),
      ],
    );
  }
}

OverlayEntry? _toast;
Timer? _toastTimer;

/// every short message the app shows.
///
/// not a snack bar: those live in a slot of the Scaffold that the drawer and
/// the bottom of the window both paint over, and the exit hint is shown with
/// the drawer open. the root overlay sits above all of it, and reading the
/// inset there keeps the message clear of the system navigation bar too
void showToast(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  hideToast();
  final entry = OverlayEntry(builder: (_) => _Toast(message: message));
  _toast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(duration, hideToast);
}

void hideToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  final entry = _toast;
  _toast = null;
  if (entry != null && entry.mounted) entry.remove();
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
      // taps belong to whatever is underneath, the message is only a message
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 160),
          builder: (_, t, child) => Opacity(opacity: t, child: child),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
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
    showToast(context, failMessage);
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
    // a coloured pill carries a faint rim of its own colour, as the plugin's do
    final tinted = color != AppColors.textSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: tinted ? color.withValues(alpha: 0.12) : background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tinted ? color.withValues(alpha: 0.4) : AppColors.line),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// an empty list, said with a quaggan from the api when one is at hand. the
/// picture is picked from the message, so it stays the same on rebuilds
class EmptyNote extends ConsumerWidget {
  const EmptyNote(this.message, {super.key, this.center = true});

  final String message;
  final bool center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quaggans = ref.watch(quaggansProvider).valueOrNull ?? const <String>[];
    final url = quaggans.isEmpty ? null : quaggans[message.hashCode.abs() % quaggans.length];
    final text = Text(
      message,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: const TextStyle(color: AppColors.muted, height: 1.4),
    );
    if (url == null) return center ? Center(child: text) : text;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        SizedBox(width: 96, height: 96, child: CachedIcon(url: url, fit: BoxFit.contain)),
        const SizedBox(height: 8),
        text,
      ],
    );
    return center ? Center(child: column) : column;
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
            Text(sub, style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted)),
          ],
          const SizedBox(height: 12),
          const Divider(),
        ],
      ),
    );
  }
}

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
            Text(cap, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
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
                Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
                if (n != null) Text(n, style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.muted)),
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

/// a note with an accent bar down its left edge, the plugin's notice card
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.text, this.icon = Icons.info_outline, this.accent = AppColors.amber});

  final String text;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
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
                      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSoft)),
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
      child:
          Text(version, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSoft)),
    );
  }
}

/// the night sky the plugin paints behind its live preview: a deep blue
/// fading to black with a scatter of four pointed stars. the stars sit in
/// the same places every time, from a fixed seed
class StageHero extends StatelessWidget {
  const StageHero({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.window),
        border: Border.all(color: AppColors.line),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.skyTop, AppColors.skyBottom],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: const _StarsPainter(),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // a small linear congruential generator, so the sky is the same on every build
    var seed = 20260926;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final count = (size.width * size.height / 2600).clamp(14, 60).round();
    for (var i = 0; i < count; i++) {
      final at = Offset(next() * size.width, next() * size.height);
      final big = next() > 0.82;
      final r = big ? 3.2 + next() * 1.6 : 0.9 + next() * 0.8;
      final alpha = big ? 0.9 : 0.35 + next() * 0.4;
      final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
      if (big) {
        // a four pointed sparkle
        final path = Path()
          ..moveTo(at.dx, at.dy - r)
          ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
          ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
          ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
          ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(at, r * 0.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => false;
}

/// shown where a whole section is about the player's account and there is no
/// api key: what it needs, and the way to give one
class NeedsKeyView extends ConsumerWidget {
  const NeedsKeyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 56),
        const Icon(Icons.vpn_key_outlined, size: 48, color: AppColors.gold),
        const SizedBox(height: 16),
        Text(s.t('needs_key_title'), textAlign: TextAlign.center, style: display(22)),
        const SizedBox(height: 10),
        Text(
          s.t('needs_key_body'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        Center(
          child: FilledButton.icon(
            onPressed: () => openAddKey(context),
            icon: const Icon(Icons.add),
            label: Text(s.t('add_api_key')),
          ),
        ),
      ],
    );
  }
}

/// the sections that are about the player's own account. the others, from
/// the world map to recipes, work without a key
bool sectionNeedsKey(AppSection section) => const {
      AppSection.daily,
      AppSection.weekly,
      AppSection.characters,
      AppSection.collections,
      AppSection.progression,
      AppSection.wvw,
      AppSection.account,
      AppSection.guilds,
    }.contains(section);
