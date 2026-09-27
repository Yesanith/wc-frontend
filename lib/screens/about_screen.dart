import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_check.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _author = 'Yesanith';
const repositoryUrl = 'https://github.com/Yesanith/tyria-companion';
const issuesUrl = '$repositoryUrl/issues';

/// where people who like the app can chip in
const supportUrl = 'https://buymeacoffee.com/yesanith';

/// who made the app, where it lives and how to help, laid out like the
/// About page of Regions of XIV: a hero, community tiles and the credits
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    const version = appVersion == 'dev' ? 'dev' : 'v$appVersion';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _Hero(version: version, by: s.t('about_by', {'name': _author}), summary: s.t('about_summary')),
        const SizedBox(height: 22),
        Text(s.t('about_community'), style: display(16)),
        const SizedBox(height: 8),
        _CommunityTile(
          icon: Icons.code,
          accent: AppColors.gold,
          title: s.t('about_github'),
          body: s.t('about_github_note'),
          url: repositoryUrl,
        ),
        _CommunityTile(
          icon: Icons.bug_report_outlined,
          accent: AppColors.red,
          title: s.t('about_issue'),
          body: s.t('about_issue_note'),
          url: issuesUrl,
        ),
        _CommunityTile(
          icon: Icons.coffee,
          accent: AppColors.coffee,
          ink: AppColors.onCoffee,
          title: s.t('buy_coffee'),
          body: s.t('support_note'),
          url: supportUrl,
          external: true,
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          title: s.t('about_credits'),
          children: [
            SettingsRow(label: s.t('about_credit_dev', {'name': _author})),
            SettingsRow(label: s.t('about_credit_data')),
            SettingsRow(label: s.t('about_credit_design')),
          ],
        ),
        Text(s.t('disclaimer'), style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.hint)),
      ],
    );
  }
}

/// the name and what the app does on a warm card with a gold rim
class _Hero extends StatelessWidget {
  const _Hero({required this.version, required this.by, required this.summary});

  final String version;
  final String by;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card * 1.6),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(AppColors.surface2, AppColors.gold, 0.18)!,
            Color.lerp(AppColors.navBg, AppColors.gold, 0.05)!,
          ],
        ),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const DiamondEmblem(size: 72),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tyria Codex', style: display(24)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [VersionPill(version), Pill(by, color: AppColors.goldSoft)],
                ),
                const SizedBox(height: 10),
                Text(summary, style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// a link with a round medallion in its own colour, the plugin's community tile
class _CommunityTile extends StatelessWidget {
  const _CommunityTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.url,
    this.ink = AppColors.onGold,
    this.external = false,
  });

  final IconData icon;
  final Color accent;
  final Color ink;
  final String title;
  final String body;
  final String url;

  /// open in the phone's browser, where people are already signed in
  final bool external;

  Future<void> _open(BuildContext context) async {
    if (!external) return openUrl(context, url);
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) await openUrl(context, url);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Color.lerp(AppColors.surface, accent, 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: Icon(icon, size: 20, color: ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(body, style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18, color: accent.withValues(alpha: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
