import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/community.dart';
import '../state/settings.dart';
import '../theme.dart';
import 'common.dart';

/// the colour Discord gives its own buttons
const discordBlurple = Color(0xFF5865F2);

/// the names of the game accounts linked to the community account, the first and how many more: Leo.1234 +1
String linkedAccountsLabel(List<String> names) =>
    names.isEmpty ? '' : (names.length == 1 ? names.first : '${names.first} +${names.length - 1}');

/// who is signed in, at the top of the menu and in the bar of the site: a button to sign in with Discord while nobody
/// is, then the Discord name with the game accounts linked to it under it. tapping it opens the settings, where the
/// account is managed. a build without the community backend has nothing to show here
class AccountBadge extends ConsumerStatefulWidget {
  const AccountBadge({super.key, required this.onOpen, this.compact = false, this.showName = true});

  /// opens the settings
  final VoidCallback onOpen;

  /// the bar of the site: one line
  final bool compact;

  /// in the bar of the site, whether there is room for the name, or only for the picture (and a button to sign in
  /// with the Discord sign alone)
  final bool showName;

  @override
  ConsumerState<AccountBadge> createState() => _AccountBadgeState();
}

class _AccountBadgeState extends ConsumerState<AccountBadge> {
  bool _busy = false;

  Future<void> _signIn() async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      await signInWithDiscord();
    } catch (_) {
      if (mounted) showToast(context, s.t('community_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!communityReady) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final session = ref.watch(sessionProvider);
    // until the session is read there is nothing to say: a button that turns into a name would only flicker
    if (session.isLoading && !session.hasValue) return const SizedBox.shrink();

    if (session.valueOrNull == null) {
      if (widget.compact && !widget.showName) {
        return IconButton.filled(
          tooltip: s.t('nav_sign_in'),
          style: IconButton.styleFrom(backgroundColor: discordBlurple, foregroundColor: Colors.white),
          onPressed: _busy ? null : _signIn,
          icon: const Icon(Icons.login, size: 18),
        );
      }
      final label = Text(s.t('nav_sign_in'), maxLines: 1, overflow: TextOverflow.ellipsis);
      final icon = _busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.login, size: 18);
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: discordBlurple,
          foregroundColor: Colors.white,
          visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
          minimumSize: widget.compact ? null : const Size.fromHeight(44),
        ),
        onPressed: _busy ? null : _signIn,
        icon: icon,
        label: label,
      );
    }

    final profile = ref.watch(myProfileProvider).valueOrNull;
    final linked = ref.watch(linkedAccountsProvider).valueOrNull;
    // the profile is the name the player has here; until it is read, or when it cannot be, what Discord gave the session
    final identity = sessionIdentity(session.valueOrNull);
    final name = profile?.displayName.isNotEmpty == true ? profile!.displayName : (identity.name ?? '…');
    final picture = profile?.avatarUrl ?? identity.avatar;
    final games = linked == null ? '' : linkedAccountsLabel([for (final a in linked) a.name]);
    final second = linked == null ? '' : (games.isEmpty ? s.t('nav_no_gw2') : games);
    final avatar = CircleAvatar(
      radius: widget.compact ? 14 : 18,
      backgroundColor: AppColors.surface2,
      foregroundImage: picture == null ? null : NetworkImage(picture),
      child: Icon(Icons.person_outline, size: widget.compact ? 16 : 20, color: AppColors.muted),
    );

    if (widget.compact) {
      return Tooltip(
        message: second.isEmpty ? name : '$name · $second',
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: widget.onOpen,
          child: Container(
            padding: EdgeInsets.fromLTRB(4, 4, widget.showName ? 12 : 4, 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatar,
                if (widget.showName) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
                        if (second.isNotEmpty)
                          Text(second,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.2)),
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

    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    if (second.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 13, color: games.isEmpty ? AppColors.amber : AppColors.gold),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(second,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(fontSize: 12, color: games.isEmpty ? AppColors.amber : AppColors.muted)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.chevron),
            ],
          ),
        ),
      ),
    );
  }
}
