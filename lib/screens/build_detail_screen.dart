import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings.dart';
import '../util.dart';
import '../widgets/build_view.dart';

class BuildDetailScreen extends ConsumerWidget {
  const BuildDetailScreen({super.key, required this.buildData});

  final Json buildData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('build')),
      ),
      body: BuildView(buildData: buildData, padding: const EdgeInsets.fromLTRB(20, 8, 20, 24)),
    );
  }
}
