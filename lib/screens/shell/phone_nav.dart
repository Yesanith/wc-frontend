part of '../shell.dart';

/// the sections a phone has along its bottom, the ones opened most. the rest are behind "more"
const _phoneTabs = [AppSection.home, AppSection.bosses, AppSection.account, AppSection.trading];

/// the short names of the tabs: the bar has the width of a phone for five of them
const _phoneTabLabels = {
  AppSection.home: 'nav_home',
  AppSection.bosses: 'tab_events',
  AppSection.account: 'nav_account',
  AppSection.trading: 'tab_trading',
};

/// what "more" lists, in the groups of the menu of the site. the tabs are not in it
const _moreGroups = <(String, List<AppSection>)>[
  (
    'nav_group_account',
    [
      AppSection.daily,
      AppSection.weekly,
      AppSection.characters,
      AppSection.progression,
      AppSection.collections,
    ]
  ),
  ('nav_group_community', [AppSection.guilds, AppSection.guildEvents, AppSection.publicEvents, AppSection.recruitment]),
  (
    'nav_group_world',
    [AppSection.recipes, AppSection.maps, AppSection.wvw, AppSection.professions, AppSection.news, AppSection.wiki]
  ),
];

/// the bar along the bottom of a phone: four sections and "more", which is lit while a section of it is open
class _PhoneTabBar extends ConsumerWidget {
  const _PhoneTabBar({required this.section, required this.onSelect, required this.onMore, required this.moreOpen});

  final AppSection section;
  final ValueChanged<AppSection> onSelect;
  final VoidCallback onMore;
  final bool moreOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final at = _phoneTabs.indexOf(section);
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppColors.navBg,
        indicatorColor: AppColors.surface3,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11.5,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
              color: states.contains(WidgetState.selected) ? AppColors.goldSoft : AppColors.muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected) ? AppColors.goldSoft : AppColors.muted,
            )),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: NavigationBar(
          selectedIndex: moreOpen || at < 0 ? _phoneTabs.length : at,
          onDestinationSelected: (i) => i == _phoneTabs.length ? onMore() : onSelect(_phoneTabs[i]),
          destinations: [
            for (final sec in _phoneTabs)
              NavigationDestination(
                icon: Icon(_icons[sec]!.$1),
                selectedIcon: Icon(_icons[sec]!.$2),
                label: s.t(_phoneTabLabels[sec]!),
              ),
            NavigationDestination(
              icon: Icon(moreOpen ? Icons.close : Icons.menu),
              label: s.t(moreOpen ? 'close' : 'tab_more'),
            ),
          ],
        ),
      ),
    );
  }
}

/// every other section, in a sheet that comes up from the bottom over the page, with the search on top: the menu of the
/// site, as a list of two columns
class _MoreSheet extends ConsumerWidget {
  const _MoreSheet({required this.current, required this.search, required this.onSelect});

  final AppSection current;
  final Widget search;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    Widget item(AppSection sec) {
      final on = sec == current;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelect(sec),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: on ? AppColors.surface3 : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(on ? _icons[sec]!.$2 : _icons[sec]!.$1, size: 20, color: AppColors.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.t(_titleKeys[sec]!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: on ? FontWeight.w800 : FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget grid(List<AppSection> sections) {
      final rows = <Widget>[];
      for (var i = 0; i < sections.length; i += 2) {
        rows.add(Row(children: [
          Expanded(child: item(sections[i])),
          const SizedBox(width: 4),
          Expanded(child: i + 1 < sections.length ? item(sections[i + 1]) : const SizedBox.shrink()),
        ]));
      }
      return Column(children: rows);
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 6), child: search),
            for (final (label, sections) in _moreGroups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
                child: Kicker(s.t(label).caps, color: AppColors.muted),
              ),
              grid(sections),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Divider(height: 1, color: AppColors.line),
            ),
            grid(const [AppSection.settings, AppSection.about]),
          ],
        ),
      ),
    );
  }
}

extension _PhoneNav on _AppShellState {
  /// "more": the sheet with every other section. picking one closes it and opens the section
  Future<void> _openMore() async {
    if (_moreOpen) {
      Navigator.of(context).maybePop();
      return;
    }
    _setMoreOpen(true);
    final width = MediaQuery.sizeOf(context).width;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: AppColors.bg,
      barrierColor: const Color(0x73140F0B),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (sheet) => _MoreSheet(
        current: ref.read(sectionProvider),
        search: _search(
          width: width - 32,
          onSelect: (hit) {
            Navigator.of(sheet).pop();
            _openHit(hit);
          },
        ),
        onSelect: (sec) {
          Navigator.of(sheet).pop();
          _select(sec);
        },
      ),
    );
    if (mounted) _setMoreOpen(false);
  }
}
