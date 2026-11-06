import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/update_check.dart' show appVersion;
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/site_header.dart';
import 'about_screen.dart' show repositoryUrl;

/// the page a visitor of the site is shown before the app asks anything of them: what the app is. it is gone once they choose to start,
/// or to look around as a guest
final landingDismissedProvider = StateProvider<bool>((ref) => false);

/// what the app has, as the page shows it: an icon, the name of the page in the app, and a line on what is in it
const landingFeatures = <(IconData, String, String)>[
  (Icons.shield_outlined, 'nav_characters', 'landing_f_characters'),
  (Icons.account_balance_wallet_outlined, 'nav_account', 'landing_f_wallet'),
  (Icons.storefront_outlined, 'trading_post', 'landing_f_trading'),
  (Icons.schedule_outlined, 'world_bosses', 'landing_f_bosses'),
  (Icons.map_outlined, 'maps', 'landing_f_map'),
  (Icons.account_tree_outlined, 'recipes', 'landing_f_recipes'),
  (Icons.event_note_outlined, 'guild_events', 'landing_f_guild'),
  (Icons.public_outlined, 'public_events', 'landing_f_public'),
];

/// how many cards of the features go side by side in a row of this width
int landingColumns(double width) => width >= 1000 ? 4 : (width >= 640 ? 2 : 1);

class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);
    final width = MediaQuery.sizeOf(context).width;
    // on a phone the row at the top has no room for the version and the name of the language
    final narrow = width < 600;
    void start() => ref.read(landingDismissedProvider.notifier).state = true;
    final startButton = FilledButton(
      onPressed: start,
      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18)),
      child: Text(s.t('landing_start')),
    );
    final guestButton = OutlinedButton(
      onPressed: () => ref.read(guestModeProvider.notifier).set(true),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18)),
      child: Text(s.t('landing_guest')),
    );
    return Scaffold(
      bottomNavigationBar: SiteFooter(
        note: s.t('site_footer_note'),
        links: [
          (
            label: s.t('site_privacy'),
            onTap: () => openUrl(context, sitePageUrl(lang, 'privacy'), failMessage: s.t('open_failed'))
          ),
          (
            label: s.t('site_terms'),
            onTap: () => openUrl(context, sitePageUrl(lang, 'terms'), failMessage: s.t('open_failed'))
          ),
          (label: s.t('site_source'), onTap: () => openUrl(context, repositoryUrl, failMessage: s.t('open_failed'))),
        ],
      ),
      body: Stack(
        children: [
          // two soft glows behind the title, as the sign in page has
          Positioned(top: -140, left: -100, child: _Glow(color: AppColors.gold.withValues(alpha: 0.18), size: 460)),
          Positioned(top: 60, right: -140, child: _Glow(color: AppColors.ember.withValues(alpha: 0.12), size: 380)),
          SafeArea(
            child: ListView(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const DiamondEmblem(size: 34),
                              const SizedBox(width: 12),
                              // the name takes what room is left, and is cut short rather than push the language button off a narrow phone
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text('Wondrous Compass',
                                          maxLines: 1, overflow: TextOverflow.ellipsis, style: display(20)),
                                    ),
                                    if (!narrow) ...[
                                      const SizedBox(width: 8),
                                      const VersionPill(appVersion == 'dev' ? 'dev' : 'v$appVersion'),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<AppLang>(
                                tooltip: s.t('language'),
                                initialValue: lang,
                                onSelected: (l) => ref.read(langProvider.notifier).set(l),
                                itemBuilder: (_) => [
                                  for (final l in AppLang.values) PopupMenuItem(value: l, child: Text(l.nativeName))
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.translate, size: 18, color: AppColors.gold),
                                      if (!narrow) ...[
                                        const SizedBox(width: 6),
                                        Text(lang.nativeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: width >= 900 ? 84 : 48),
                          Text(
                            s.t('landing_title'),
                            textAlign: TextAlign.center,
                            style: display(width >= 900 ? 54 : 36),
                          ),
                          const SizedBox(height: 18),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 700),
                            child: Text(
                              s.t('landing_sub'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 17, height: 1.55, color: AppColors.muted),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [startButton, guestButton]),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 14, color: AppColors.hint),
                              const SizedBox(width: 6),
                              Flexible(
                                  child:
                                      Text(s.t('privacy_note'), style: TextStyle(fontSize: 12, color: AppColors.hint))),
                            ],
                          ),
                          SizedBox(height: width >= 900 ? 84 : 48),
                          LayoutBuilder(
                            builder: (context, box) {
                              final columns = landingColumns(box.maxWidth);
                              final cardWidth = (box.maxWidth - (columns - 1) * 16) / columns;
                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  for (final (icon, title, body) in landingFeatures)
                                    SizedBox(
                                      width: cardWidth,
                                      child: Panel(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.gold.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(icon, color: AppColors.gold, size: 24),
                                            ),
                                            const SizedBox(height: 14),
                                            Text(s.t(title),
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                            const SizedBox(height: 6),
                                            Text(s.t(body),
                                                style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.muted)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 56),
                          Panel(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                            child: Column(
                              children: [
                                Text(s.t('landing_title'), textAlign: TextAlign.center, style: display(24)),
                                const SizedBox(height: 18),
                                Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    alignment: WrapAlignment.center,
                                    children: [startButton, guestButton]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// a soft round light behind the title
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
