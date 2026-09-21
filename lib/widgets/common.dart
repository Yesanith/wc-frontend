import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/gw2_api.dart';
import '../screens/goals_screen.dart';
import '../screens/trading_screen.dart';
import '../state/providers.dart';
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

class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorBox(message: '$e', onRetry: onRetry),
    );
  }
}

/// like AsyncView, but a 401 or 403 means the api key is missing a
/// permission rather than something being broken
class PermissionAsyncView<T> extends ConsumerWidget {
  const PermissionAsyncView({
    super.key,
    required this.value,
    required this.builder,
    required this.permission,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final String permission;
  final VoidCallback? onRetry;

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
        if (e is Gw2ApiException && (e.status == 401 || e.status == 403)) {
          return Panel(
            child: Text(s.t('needs_permission', {'p': permission}),
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

void showItemSheet(
  BuildContext context, {
  required int id,
  required String name,
  String? icon,
  String? rarity,
  String? type,
  int count = 1,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => Consumer(
      // keep the outer context for navigation, the sheet one is gone after pop
      builder: (_, ref, __) {
        final s = ref.watch(stringsProvider);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ItemIcon(url: icon, rarity: rarity, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            [if (rarity != null) rarity, if (type != null) type, if (count > 1) 'x$count'].join(' · '),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: rarityColor(rarity)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    openWikiPage(context, ref, name);
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(s.t('open_in_wiki')),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => TradingItemScreen(itemId: id)),
                          );
                        },
                        icon: const Icon(Icons.storefront_outlined),
                        label: Text(s.t('trading_post')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          showAddToGoalSheet(context, itemId: id, itemName: name);
                        },
                        icon: const Icon(Icons.flag_outlined),
                        label: Text(s.t('add_to_goal')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
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
