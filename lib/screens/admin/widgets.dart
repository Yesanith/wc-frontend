import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../state/admin.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/responsive.dart';

class AdminLimitBar extends StatelessWidget {
  const AdminLimitBar(this.label, this.used, this.limit, this.usedText, this.limitText, {super.key});

  final String label;
  final int used;
  final int limit;
  final String usedText;
  final String limitText;

  @override
  Widget build(BuildContext context) {
    final fraction = limit == 0 ? 0.0 : used / limit;
    final color = switch (levelOfUse(fraction)) {
      HealthLevel.good => AppColors.green,
      HealthLevel.warn => AppColors.amber,
      HealthLevel.bad => AppColors.red,
    };
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('$usedText of $limitText', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.track,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(fraction * 100).toStringAsFixed(fraction < 0.1 ? 1 : 0)} percent',
              style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ parts they share

class AdminStatGrid extends StatelessWidget {
  const AdminStatGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView(
      gridDelegate: const AdaptiveGridDelegate(
        minColumns: 2,
        maxTile: 230,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 104,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

class AdminStat extends StatelessWidget {
  const AdminStat(this.label, this.value, this.note, {super.key});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.hint)),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.gold)),
          Text(note,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class AdminLine extends StatelessWidget {
  const AdminLine(this.label, this.value, {super.key, this.valueColor, this.bold = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: bold ? AppColors.text : AppColors.textSoft)),
          ),
          Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? AppColors.muted)),
        ],
      ),
    );
  }
}

class AdminDot extends StatelessWidget {
  const AdminDot(this.level, {super.key});

  final HealthLevel level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      HealthLevel.good => AppColors.green,
      HealthLevel.warn => AppColors.amber,
      HealthLevel.bad => AppColors.red,
    };
    return Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class AdminHealth extends StatelessWidget {
  const AdminHealth(this.lines, {super.key});

  final List<HealthLine> lines;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 5), child: AdminDot(line.level)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(line.detail, style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35)),
                      ],
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

class AdminBars extends StatelessWidget {
  const AdminBars({super.key, required this.title, required this.days, this.summary});

  final String title;
  final List<({String day, int count})> days;

  /// what to say in the corner: by default the sum, for numbers that are kept day by day what it is now
  final String Function(List<int> values)? summary;

  @override
  Widget build(BuildContext context) {
    final values = [for (final d in days) d.count];
    final total = values.fold<int>(0, (a, b) => a + b);
    final peak = values.isEmpty ? 0 : values.reduce(math.max);
    String short(String day) => day.length >= 10 ? day.substring(5) : day;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(summary?.call(values) ?? '$total in 30 days',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 70, width: double.infinity, child: CustomPaint(painter: AdminBarsPainter(values))),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(days.isEmpty ? '' : short(days.first.day), style: TextStyle(fontSize: 11, color: AppColors.hint)),
              Text(summary == null ? 'most in a day: $peak' : 'most: $peak',
                  style: TextStyle(fontSize: 11, color: AppColors.hint)),
              Text(days.isEmpty ? '' : short(days.last.day), style: TextStyle(fontSize: 11, color: AppColors.hint)),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminBarsPainter extends CustomPainter {
  AdminBarsPainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final top = values.reduce(math.max);
    final slot = size.width / values.length;
    final full = Paint()..color = AppColors.gold;
    final none = Paint()..color = AppColors.track;
    for (var i = 0; i < values.length; i++) {
      final h = top == 0 ? 0.0 : size.height * values[i] / top;
      final bar = math.max(h, 2.0);
      final rect = Rect.fromLTWH(i * slot + slot * 0.15, size.height - bar, slot * 0.7, bar);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), values[i] == 0 ? none : full);
    }
  }

  @override
  bool shouldRepaint(AdminBarsPainter oldDelegate) => oldDelegate.values != values;
}

// ------------------------------------------------------------------ history

/// which versions of the app were opened this week, the newest first, each with its share
class AdminVersions extends StatelessWidget {
  const AdminVersions(this.history, {super.key});

  final AdminHistory history;

  @override
  Widget build(BuildContext context) {
    final problem = history.problem('app_versions');
    if (problem != null) return Panel(child: Text(problem, style: TextStyle(color: AppColors.amber)));
    final rows = history.appVersions.where((v) => v.week > 0).toList();
    if (rows.isEmpty) {
      return Panel(
        child: Text(
            'No version has been opened since the counting began, a version is counted when the app is opened by a signed in player.',
            style: TextStyle(color: AppColors.muted, height: 1.4)),
      );
    }
    final total = rows.fold<int>(0, (a, v) => a + v.week);
    final share = history.newestVersionShare;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (share != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${(share * 100).round()} percent of the opens were of the newest version',
                  style: TextStyle(fontSize: 12, color: share >= 0.5 ? AppColors.green : AppColors.amber)),
            ),
          for (final v in rows.take(12))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 70, child: Text(v.platform, style: TextStyle(fontSize: 12, color: AppColors.muted))),
                  SizedBox(
                      width: 70,
                      child: Text(v.version, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                          value: v.week / total, minHeight: 6, color: AppColors.gold, backgroundColor: AppColors.track),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(fmtInt(v.week),
                        textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ public events

/// a tab of numbers: pull to refresh, a width it can be read in, and the parts in two columns where there is room
class AdminTab extends StatelessWidget {
  const AdminTab(
      {super.key, required this.updated, required this.onRefresh, required this.primary, this.secondary = const []});

  final DateTime? updated;
  final Future<void> Function() onRefresh;
  final List<Widget> primary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    return ContentFrame(
      child: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              updated == null ? '' : 'Updated ${ago(updated!, DateTime.now())}',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            SplitColumns(primary: primary, secondary: secondary),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ overview
