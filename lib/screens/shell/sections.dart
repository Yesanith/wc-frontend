part of '../shell.dart';

/// pages that are one long list: a row across a whole screen of a computer is hard to read
const _readingSections = {
  AppSection.news,
  AppSection.recipes,
  AppSection.progression,
  AppSection.weekly,
  AppSection.guilds,
  AppSection.wvw,
  AppSection.about,
  AppSection.settings,
};

const _titleKeys = {
  AppSection.home: 'nav_home',
  AppSection.daily: 'nav_daily',
  AppSection.weekly: 'nav_weekly',
  AppSection.characters: 'nav_characters',
  AppSection.collections: 'collections',
  AppSection.progression: 'progression',
  AppSection.wvw: 'wvw',
  AppSection.account: 'nav_account',
  AppSection.guilds: 'guilds',
  AppSection.guildEvents: 'guild_events',
  AppSection.publicEvents: 'public_events',
  AppSection.recruitment: 'recruitment',
  AppSection.trading: 'trading_post',
  AppSection.bosses: 'world_bosses',
  AppSection.maps: 'maps',
  AppSection.recipes: 'recipes',
  AppSection.professions: 'professions',
  AppSection.wiki: 'nav_wiki',
  AppSection.news: 'news',
  AppSection.settings: 'nav_settings',
  AppSection.about: 'about',
};

const _icons = {
  AppSection.home: (Icons.home_outlined, Icons.home),
  AppSection.daily: (Icons.today_outlined, Icons.today),
  AppSection.weekly: (Icons.date_range_outlined, Icons.date_range),
  AppSection.characters: (Icons.shield_outlined, Icons.shield),
  AppSection.collections: (Icons.auto_awesome_outlined, Icons.auto_awesome),
  AppSection.progression: (Icons.emoji_events_outlined, Icons.emoji_events),
  AppSection.wvw: (Icons.fort_outlined, Icons.fort),
  AppSection.account: (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
  AppSection.guilds: (Icons.groups_outlined, Icons.groups),
  AppSection.guildEvents: (Icons.event_note_outlined, Icons.event_note),
  AppSection.publicEvents: (Icons.public_outlined, Icons.public),
  AppSection.recruitment: (Icons.person_search_outlined, Icons.person_search),
  AppSection.trading: (Icons.storefront_outlined, Icons.storefront),
  AppSection.bosses: (Icons.schedule_outlined, Icons.schedule),
  AppSection.maps: (Icons.map_outlined, Icons.map),
  AppSection.recipes: (Icons.account_tree_outlined, Icons.account_tree),
  AppSection.professions: (Icons.school_outlined, Icons.school),
  AppSection.wiki: (Icons.menu_book_outlined, Icons.menu_book),
  AppSection.news: (Icons.newspaper_outlined, Icons.newspaper),
  AppSection.settings: (Icons.settings_outlined, Icons.settings),
  AppSection.about: (Icons.info_outline, Icons.info),
};

/// where a group of the menu begins, and its heading. settings and about
/// get a divider without a heading
const _groupStarts = <AppSection, String?>{
  AppSection.characters: 'nav_group_account',
  AppSection.trading: 'nav_group_economy',
  AppSection.maps: 'nav_group_world',
  AppSection.professions: 'nav_group_reference',
  AppSection.settings: null,
};

Widget _page(AppSection section) => switch (section) {
  AppSection.home => const HomeScreen(),
  AppSection.daily => const DailyScreen(),
  AppSection.weekly => const WeeklyScreen(),
  AppSection.characters => const CharactersScreen(),
  AppSection.collections => const CollectionsScreen(),
  AppSection.progression => const ProgressionScreen(),
  AppSection.wvw => const WvwScreen(),
  AppSection.account => const AccountScreen(),
  AppSection.guilds => const GuildsScreen(),
  AppSection.guildEvents => const GuildEventsScreen(),
  AppSection.publicEvents => const OpenEventsScreen(),
  AppSection.recruitment => const RecruitmentScreen(),
  AppSection.trading => const TradingHubScreen(),
  AppSection.bosses => const EventsScreen(embedded: true),
  AppSection.maps => const WorldMapScreen(),
  AppSection.recipes => const RecipesScreen(),
  AppSection.professions => const ProfessionsScreen(),
  AppSection.wiki => const WikiScreen(),
  AppSection.news => const NewsScreen(),
  AppSection.settings => const SettingsScreen(),
  AppSection.about => const AboutScreen(),
};
