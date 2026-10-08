import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/gw2_api.dart';
import '../../screens/onboarding_screen.dart';
import '../../services/icon_cache.dart';
import '../../state/api.dart';
import '../../state/navigation.dart';
import '../../state/reference.dart';
import '../../state/settings.dart';
import '../../theme.dart';
import 'labels.dart';
import 'surfaces.dart';

/// visible long enough to feel deliberate
Future<void> refreshProviders(WidgetRef ref, List<ProviderOrFamily> providers) async {
  // without this the cached copy would come straight back
  ref.read(gw2ApiProvider).forceNetwork();
  for (final provider in providers) {
    ref.invalidate(provider);
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
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
              Icon(Icons.error_outline, color: AppColors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: TextStyle(color: AppColors.textSoft, fontSize: 14)),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(detail,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.hint, fontSize: 11)),
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
              child: Text(note, style: TextStyle(color: AppColors.muted, height: 1.5)),
            );
          }
        }
        return ErrorBox(error: e, onRetry: onRetry);
      },
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
      style: TextStyle(color: AppColors.muted, height: 1.4),
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
        Icon(Icons.vpn_key_outlined, size: 48, color: AppColors.gold),
        const SizedBox(height: 16),
        Text(s.t('needs_key_title'), textAlign: TextAlign.center, style: display(22)),
        const SizedBox(height: 10),
        Text(
          s.t('needs_key_body'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.muted),
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
