import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/icon_cache.dart';
import '../state/account.dart';
import '../state/builds.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import 'build_detail_screen.dart';
import 'item_sheet.dart';
import '../state/wealth.dart';
import '../widgets/coin_text.dart';

part 'account/panels.dart';
part 'account/tabs.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          // refreshing is a pull on each tab, a row of its own above the
          // tabs only left an empty band
          AppTabBar(
            scrollable: true,
            labels: [s.t('wallet'), s.t('bank'), s.t('materials'), s.t('armory'), s.t('builds')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Pull(
                    providers: [walletProvider, accountLuckProvider, accountProgressionProvider],
                    child: const ContentFrame(maxWidth: readingMaxWidth, child: _WalletTab())),
                _Pull(providers: [bankProvider], child: const _BankTab()),
                _Pull(providers: [materialGroupsProvider], child: const _MaterialsTab()),
                _Pull(
                    providers: [armoryProvider],
                    child: const ContentFrame(maxWidth: readingMaxWidth, child: _ArmoryTab())),
                _Pull(
                    providers: [buildStorageProvider],
                    child: const ContentFrame(maxWidth: readingMaxWidth, child: _BuildsTab())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
