import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/update_check.dart' show appVersion;
import '../state/navigation.dart';
import '../theme.dart';
import 'common.dart';
import 'responsive.dart';

part 'site_header/footer.dart';

/// the page address of the static site, where the privacy policy and the terms are, in the language of the app: English at the root,
/// the others in a folder of their own
const siteBase = 'https://yesanith.github.io/wc-frontend/';

String sitePageUrl(AppLang lang, String page) =>
    lang == AppLang.en ? '$siteBase$page.html' : '$siteBase${lang.code}/$page.html';

/// the sections that stand on their own in the bar of a site, and the groups of the others, each with the key of its heading.
/// settings and about are at the end of the bar. every section is in one of them: what is not could not be reached
const siteNavSingles = [AppSection.home, AppSection.bosses, AppSection.daily, AppSection.weekly];

const siteNavGroups = <(String, List<AppSection>)>[
  (
    'nav_group_account',
    [
      AppSection.characters,
      AppSection.account,
      AppSection.progression,
      AppSection.collections,
    ],
  ),
  // what is done with other players: the guild, its events, public events and recruiting
  (
    'nav_group_community',
    [
      AppSection.guilds,
      AppSection.guildEvents,
      AppSection.publicEvents,
      AppSection.recruitment,
    ],
  ),
  ('nav_group_economy', [AppSection.trading, AppSection.recipes]),
  ('nav_group_world', [AppSection.maps, AppSection.wvw]),
  ('nav_group_reference', [AppSection.professions, AppSection.wiki, AppSection.news]),
];

/// the narrowest window that is shown as a site, with the bar along the top. a narrower one, a phone, is shown as an app
const siteMinWidth = 768.0;

/// from this width the bar has every section and group along it
const siteBarFullWidth = 1360.0;

/// from this width the bar has the groups along it, the pages of the day in a group of their own and the home page behind
/// the name; below it the bar has a button that opens the menu, as a site does on a tablet
const siteBarGroupedWidth = 1024.0;

/// the pages of the day, in one group where the bar has no room for them one by one
const siteTodayGroup = ('nav_group_today', [AppSection.bosses, AppSection.daily, AppSection.weekly]);

/// how the bar holds the sections at a width
enum SiteBarNav { full, grouped, menu }

SiteBarNav siteBarNav(double width) => width >= siteBarFullWidth
    ? SiteBarNav.full
    : width >= siteBarGroupedWidth
        ? SiteBarNav.grouped
        : SiteBarNav.menu;

/// how wide the bar may grow. wider than a page: the sections, the search and the account are more than a page's width
/// holds in the longer languages, and the search was drawn over the last of the sections
const siteBarMaxWidth = 1880.0;

/// what the bar has room for at a width: a search box of a width, the name of the account beside its picture, and the
/// version beside the name of the app; or the search as a button that opens it in a window and the picture alone, so that
/// the sections are never pushed out of the bar. the room is a width of the window, the bar is at most [siteBarMaxWidth]
({double? searchWidth, bool account, bool version}) siteBarLayout(double width) {
  if (width >= 1900) return (searchWidth: 260, account: true, version: true);
  if (width >= 1700) return (searchWidth: 200, account: false, version: true);
  if (width >= 1500) return (searchWidth: null, account: false, version: true);
  return (searchWidth: null, account: false, version: false);
}

/// which group a section is in, by its place in [siteNavGroups], or null for one that stands alone
int? siteGroupIndex(AppSection section) {
  for (var i = 0; i < siteNavGroups.length; i++) {
    if (siteNavGroups[i].$2.contains(section)) return i;
  }
  return null;
}

/// what the tab of the browser says: the name of the page and of the site, the site alone for its home page
String sitePageTitle(AppSection section, String name) =>
    section == AppSection.home ? 'Wondrous Compass' : '$name · Wondrous Compass';

/// the bar at the top of the page on a wide screen in a browser: the name, the sections along it, the groups opening under their heading,
/// the account and the settings at the end. it is what a site has in place of the menu beside the page that an app has
class SiteHeader extends StatelessWidget implements PreferredSizeWidget {
  const SiteHeader({
    super.key,
    required this.current,
    required this.onSelect,
    required this.labels,
    required this.icons,
    required this.groupLabels,
    required this.account,
    this.accountBadge,
    this.search,
    this.busy = false,
    this.progress,
    this.todayLabel = '',
    this.onMenu,
  });

  /// the heading of the pages of the day where they are a group, [siteTodayGroup]
  final String todayLabel;

  /// opens the menu, where the bar has no room for the sections
  final VoidCallback? onMenu;

  final AppSection current;
  final ValueChanged<AppSection> onSelect;
  final Map<AppSection, String> labels;
  final Map<AppSection, IconData> icons;

  /// the heading of each group, in the order of [siteNavGroups]
  final List<String> groupLabels;
  final String? account;

  /// who is signed in to the community account, or a way to sign in, in place of [account] when it is given
  final Widget? accountBadge;

  /// the box to search in, between the sections and the account
  final Widget? search;

  /// something is being updated: the thin bar along the foot of the header, with how far it is or none
  final bool busy;
  final double? progress;

  static const height = 64.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mode = siteBarNav(width);
    final nav = <Widget>[
      if (mode == SiteBarNav.full)
        for (final sec in siteNavSingles)
          SiteNavButton(label: labels[sec]!, selected: current == sec, onTap: () => onSelect(sec))
      else if (mode == SiteBarNav.grouped)
        _SiteNavMenu(
          label: todayLabel,
          sections: siteTodayGroup.$2,
          current: current,
          labels: labels,
          icons: icons,
          onSelect: onSelect,
        ),
      if (mode != SiteBarNav.menu)
        for (var i = 0; i < siteNavGroups.length; i++)
          _SiteNavMenu(
            label: groupLabels[i],
            sections: siteNavGroups[i].$2,
            current: current,
            labels: labels,
            icons: icons,
            onSelect: onSelect,
          ),
    ];
    return Material(
      color: AppColors.navBg,
      child: Container(
        height: height,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: siteBarMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      if (mode == SiteBarNav.menu && onMenu != null) ...[
                        IconButton(
                          tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                          onPressed: onMenu,
                          icon: const Icon(Icons.menu),
                        ),
                        const SizedBox(width: 4),
                      ],
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onSelect(AppSection.home),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Row(
                            children: [
                              const DiamondEmblem(size: 30),
                              // between the full bar and a tablet the name gives its room to the sections; the emblem
                              // still leads home
                              if (mode != SiteBarNav.grouped || width >= 1200) ...[
                                const SizedBox(width: 10),
                                Text('Wondrous Compass', style: display(20)),
                              ],
                              if (siteBarLayout(width).version) ...[
                                const SizedBox(width: 8),
                                const VersionPill(appVersion == 'dev' ? 'dev' : 'v$appVersion'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // a window just wide enough has more sections than room: the bar scrolls sideways rather than overflow
                      Expanded(
                        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: nav)),
                      ),
                      const SizedBox(width: 12),
                      if (search != null) ...[search!, const SizedBox(width: 12)],
                      Container(width: 1, height: 28, color: AppColors.line),
                      const SizedBox(width: 12),
                      if (accountBadge != null)
                        Padding(padding: const EdgeInsets.only(right: 6), child: accountBadge)
                      else if (account != null)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline, size: 16, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(account!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      IconButton(
                        tooltip: labels[AppSection.settings],
                        onPressed: () => onSelect(AppSection.settings),
                        icon: Icon(
                          icons[AppSection.settings],
                          color: current == AppSection.settings ? AppColors.gold : AppColors.muted,
                        ),
                      ),
                      IconButton(
                        tooltip: labels[AppSection.about],
                        onPressed: () => onSelect(AppSection.about),
                        icon: Icon(
                          icons[AppSection.about],
                          color: current == AppSection.about ? AppColors.gold : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // a line of the colour of the site along the very top, fading at both ends
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.transparent, AppColors.gold.withValues(alpha: 0.7), Colors.transparent]),
                ),
              ),
            ),
            if (busy)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: AppColors.track,
                  color: AppColors.gold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// one entry of the bar: its name, in gold with a line under it while it is the page, and what comes after it (the arrow of a menu)
class SiteNavButton extends StatelessWidget {
  const SiteNavButton({super.key, required this.label, required this.selected, required this.onTap, this.trailing});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.surface2.withValues(alpha: 0.7),
      focusColor: AppColors.surface2,
      child: Container(
        height: SiteHeader.height,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.07) : null,
          border: Border(bottom: BorderSide(color: selected ? AppColors.gold : Colors.transparent, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.gold : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 2), trailing!],
          ],
        ),
      ),
    );
  }
}

/// a group of sections opening under its heading
class _SiteNavMenu extends StatelessWidget {
  const _SiteNavMenu({
    required this.label,
    required this.sections,
    required this.current,
    required this.labels,
    required this.icons,
    required this.onSelect,
  });

  final String label;
  final List<AppSection> sections;
  final AppSection current;
  final Map<AppSection, String> labels;
  final Map<AppSection, IconData> icons;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.line)),
        ),
      ),
      menuChildren: [
        for (final sec in sections)
          MenuItemButton(
            leadingIcon: Icon(icons[sec], size: 20, color: sec == current ? AppColors.gold : AppColors.muted),
            onPressed: () => onSelect(sec),
            child: Text(
              labels[sec]!,
              style: TextStyle(fontWeight: FontWeight.w600, color: sec == current ? AppColors.gold : null),
            ),
          ),
      ],
      builder: (context, controller, _) => SiteNavButton(
        label: label,
        selected: sections.contains(current),
        trailing: Icon(Icons.expand_more, size: 18, color: AppColors.muted),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
