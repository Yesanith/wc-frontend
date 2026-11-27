part of '../world_map_screen.dart';

/// the chosen map in a light frame, and the rest of the world a little darker so the map stands out
class _ChosenMapPainter extends CustomPainter {
  const _ChosenMapPainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(outside, Paint()..color = const Color(0x38140F0B));
    canvas.drawRRect(
      frame,
      Paint()
        ..color = const Color(0x8CF0D08A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = const Color(0xFFF0D08A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ChosenMapPainter old) => old.rect != rect;
}

/// a floating box over the map, in the colours of the page
BoxDecoration _floating() => BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
      boxShadow: const [BoxShadow(color: Color(0x4D140F0B), blurRadius: 30, offset: Offset(0, 10))],
    );

Widget _kicker(String text) => Text(text.caps,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.muted));

/// the marker tapped on a site, beside it: its name, what it is and where, and its chat link
class _MarkerPopover extends ConsumerWidget {
  const _MarkerPopover({required this.marker, required this.icon, required this.kindLabel, required this.onClose});

  final MapMarker marker;
  final String? icon;
  final String kindLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: _floating().copyWith(borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 22,
              height: 22,
              child: _MarkerIcon(kind: marker.kind, icon: icon, region: marker.kind == 'mastery' ? marker.name : '')),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(marker.name.isEmpty || marker.kind == 'mastery' ? kindLabel : marker.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                Text(marker.mapName.isEmpty ? kindLabel : '$kindLabel · ${marker.mapName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          if (marker.chatLink.isNotEmpty) ...[
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.onGold,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              onPressed: () => copyWaypoint(context, ref, Waypoint(marker.name, marker.chatLink)),
              child: Text(s.t('map_copy_link')),
            ),
          ],
          IconButton(
            tooltip: s.t('close'),
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Icon(Icons.close, size: 16, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// a site's left panel: the search, then what the map shows, each kind with how many the chosen map has
class _LayersPanel extends ConsumerWidget {
  const _LayersPanel({
    required this.search,
    required this.layers,
    required this.icons,
    required this.counts,
    required this.kindLabel,
    required this.onToggle,
  });

  final Widget search;
  final Set<String> layers;
  final Map<String, String> icons;
  final Map<String, int> counts;
  final String Function(String kind) kindLabel;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _floating(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: 14),
          _kicker(s.t('map_on_map')),
          const SizedBox(height: 4),
          for (final k in markerKinds)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onToggle(k),
              child: SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Checkbox(
                      value: layers.contains(k),
                      activeColor: AppColors.gold,
                      visualDensity: VisualDensity.compact,
                      onChanged: (_) => onToggle(k),
                    ),
                    SizedBox(width: 20, height: 20, child: _MarkerIcon(kind: k, icon: icons[k])),
                    const SizedBox(width: 10),
                    Expanded(child: Text(kindLabel(k), style: const TextStyle(fontSize: 14))),
                    if (counts.isNotEmpty)
                      Text('${counts[k] ?? 0}', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          if (counts.isEmpty) ...[
            const SizedBox(height: 8),
            Text(s.t('map_tap_hint'), style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

/// a phone's layers: a row of chips under the search, one tap each
class _LayerChips extends StatelessWidget {
  const _LayerChips({required this.layers, required this.kindLabel, required this.onToggle});

  final Set<String> layers;
  final String Function(String kind) kindLabel;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final k in markerKinds)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                selected: layers.contains(k),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                selectedColor: AppColors.header,
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.line),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: layers.contains(k) ? AppColors.onHeader : AppColors.text,
                ),
                label: Text(kindLabel(k)),
                onSelected: (_) => onToggle(k),
              ),
            ),
        ],
      ),
    );
  }
}

/// the floors of the map: a row of levels on a site, a menu on a phone
class _FloorPicker extends StatelessWidget {
  const _FloorPicker({required this.floor, required this.label, required this.onPick, this.compact = false});

  final int floor;
  final String Function(int floor) label;
  final ValueChanged<int> onPick;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return PopupMenuButton<int>(
        initialValue: floor,
        color: AppColors.surface,
        onSelected: onPick,
        tooltip: label(floor),
        itemBuilder: (context) => [for (final f in worldFloors) PopupMenuItem(value: f, child: Text(label(f)))],
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _floating().copyWith(borderRadius: BorderRadius.circular(24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.stairs_outlined, size: 18, color: AppColors.gold),
            const SizedBox(width: 4),
            Text('$floor', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: _floating().copyWith(borderRadius: BorderRadius.circular(22)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in worldFloors)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: f == floor ? AppColors.gold : Colors.transparent,
                  foregroundColor: f == floor ? AppColors.onGold : AppColors.text,
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onPressed: () => onPick(f),
                child: Text(label(f)),
              ),
            ),
        ],
      ),
    );
  }
}

/// in, out, and back to the whole of tyria, for a mouse without a wheel
class _ZoomButtons extends ConsumerWidget {
  const _ZoomButtons({required this.onIn, required this.onOut, required this.onWhole});

  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onWhole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    Widget button(IconData icon, String tip, VoidCallback onTap) =>
        IconButton(tooltip: tip, onPressed: onTap, icon: Icon(icon, size: 20, color: AppColors.text));
    return Container(
      decoration: _floating().copyWith(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.add, s.t('zoom_in'), onIn),
          Container(width: 32, height: 1, color: AppColors.line),
          button(Icons.remove, s.t('zoom_out'), onOut),
          Container(width: 32, height: 1, color: AppColors.line),
          button(Icons.fullscreen_exit, s.t('map_whole'), onWhole),
        ],
      ),
    );
  }
}

/// the chosen map: its region and levels, what it has, the timed events on it, its waypoints, and the wiki. at the
/// right of a site, a card at the bottom of a phone
class _MapCard extends ConsumerStatefulWidget {
  const _MapCard({
    required this.name,
    required this.detail,
    required this.markers,
    required this.compact,
    required this.onClose,
    required this.onWaypoint,
  });

  final String name;
  final MapDetail? detail;
  final List<MapMarker> markers;
  final bool compact;
  final VoidCallback onClose;
  final ValueChanged<MapMarker> onWaypoint;

  @override
  ConsumerState<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends ConsumerState<_MapCard> {
  bool _allWaypoints = false;

  @override
  void didUpdateWidget(_MapCard old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _allWaypoints = false;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final d = widget.detail;
    final icons = ref.watch(markerIconsProvider).valueOrNull ?? const <String, String>{};
    final waypoints = [
      for (final m in widget.markers)
        if (m.kind == 'waypoint') m
    ]..sort((a, b) => a.name.compareTo(b.name));
    final counts = <String, int>{};
    for (final m in widget.markers) {
      counts[m.kind] = (counts[m.kind] ?? 0) + 1;
    }
    final events = [
      for (final m in ref.watch(shownMetaMapsProvider))
        for (final e in m.events)
          if (m.name == widget.name || e.name == widget.name) (m, e)
    ];
    final kicker = [
      if (d != null && d.region.isNotEmpty) d.region,
      // a city has no levels, the api gives it 0 to 80
      if (d != null && d.minLevel > 0) s.t('map_level_range', {'a': d.minLevel, 'b': d.maxLevel}),
    ].join(' · ');
    final shown = _allWaypoints ? waypoints : waypoints.take(5).toList();

    final header = Container(
      padding: EdgeInsets.fromLTRB(18, widget.compact ? 10 : 16, 8, 14),
      color: AppColors.header,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.compact)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: AppColors.onHeader.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kicker.isNotEmpty)
                      Text(kicker.caps,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.accent)),
                    const SizedBox(height: 2),
                    Text(widget.name, style: display(widget.compact ? 24 : 30, color: const Color(0xFFFFF8E6))),
                  ],
                ),
              ),
              IconButton(
                tooltip: s.t('close'),
                onPressed: widget.onClose,
                icon: Icon(Icons.close, color: AppColors.onHeader, size: 20),
              ),
            ],
          ),
        ],
      ),
    );

    final body = <Widget>[
      // what the map has, by kind
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final k in markerKinds)
            if ((counts[k] ?? 0) > 0)
              Tooltip(
                message: s.t('marker_$k'),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 18, height: 18, child: _MarkerIcon(kind: k, icon: icons[k])),
                    const SizedBox(width: 6),
                    Text('${counts[k]}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
        ],
      ),
      if (events.isNotEmpty) ...[
        const SizedBox(height: 16),
        _kicker(s.t('map_events_here')),
        const SizedBox(height: 8),
        ClockBuilder(
          step: ClockStep.minute,
          builder: (context, now) => Column(
            children: [for (final (m, e) in events) _EventLine(map: m, event: e, now: now, mapName: widget.name)],
          ),
        ),
      ],
      if (waypoints.isNotEmpty) ...[
        const SizedBox(height: 16),
        _kicker(s.t('marker_waypoint')),
        const SizedBox(height: 4),
        for (final w in shown)
          InkWell(
            onTap: () => widget.onWaypoint(w),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  SizedBox(width: 18, height: 18, child: _MarkerIcon(kind: 'waypoint', icon: icons['waypoint'])),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(w.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
                  if (w.chatLink.isNotEmpty)
                    TextButton(
                      onPressed: () => copyWaypoint(context, ref, Waypoint(w.name, w.chatLink)),
                      child: Text(s.t('copy')),
                    ),
                ],
              ),
            ),
          ),
        if (waypoints.length > 5)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _allWaypoints = !_allWaypoints),
              child: Text(_allWaypoints ? s.t('show_less') : s.t('show_all_n', {'n': waypoints.length})),
            ),
          ),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.onGold),
              onPressed: () => openWikiPage(context, ref, widget.name),
              child: Text(s.t('map_open_wiki')),
            ),
          ),
          if (events.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.bosses,
                child: Text(s.t('all_timers')),
              ),
            ),
          ],
        ],
      ),
    ];

    return Container(
      decoration: widget.compact
          ? BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: const [BoxShadow(color: Color(0x59140F0B), blurRadius: 24, offset: Offset(0, -8))],
            )
          : _floating(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 16, 18, widget.compact ? 18 + MediaQuery.paddingOf(context).bottom : 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
        ],
      ),
    );
  }
}

/// one timed event of the chosen map: when it comes next, its waypoint, and a pin
class _EventLine extends ConsumerWidget {
  const _EventLine({required this.map, required this.event, required this.now, required this.mapName});

  final MetaMap map;
  final String mapName;
  final MetaEvent event;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final key = eventKey(map, event);
    final pinned = ref.watch(pinnedEventsProvider).contains(key);
    final next = occurrences(now, now.add(const Duration(days: 1)), maps: [map])
        .where((o) => o.event == event && o.end.isAfter(now))
        .firstOrNull;
    final waypoint = waypointFor(map, event);
    final start = next?.start.toLocal();
    // an event named after the map it is held on (the ley-line anomaly) is called by its own name
    final title = event.name == mapName ? map.name : event.name;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Text(start == null ? '–' : '${pad2(start.hour)}:${pad2(start.minute)}',
              style: display(20, color: AppColors.gold)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                if (next != null)
                  Text(
                    next.activeAt(now)
                        ? s.t('event_running')
                        : s.t('event_starts_in', {'t': countdown(next.start.difference(now))}),
                    style: TextStyle(fontSize: 12, color: next.activeAt(now) ? AppColors.green : AppColors.muted),
                  ),
              ],
            ),
          ),
          if (waypoint != null)
            IconButton(
              tooltip: waypoint.name,
              onPressed: () => copyWaypoint(context, ref, waypoint),
              icon: Icon(Icons.place_outlined, size: 20, color: AppColors.gold),
            ),
          IconButton(
            tooltip: pinned ? s.t('unpin') : s.t('pin'),
            onPressed: () => togglePin(context, ref, key),
            icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 20, color: AppColors.gold),
          ),
        ],
      ),
    );
  }
}
