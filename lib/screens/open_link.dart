import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/navigation.dart';
import 'item_detail_screen.dart' show showItemDetails;
import 'open_event_screen.dart' show showOpenEvent;

/// opens what a link is, over the page the app is at: an item's sheet, a public event's page, or a page of the app. [announce] is false for a link that
/// was followed or that the app was opened with, whose address the browser already has
void openLinkNow(BuildContext context, AppLink link, {bool announce = true}) {
  switch (link) {
    case SectionLink(:final section):
      ProviderScope.containerOf(context, listen: false).read(sectionProvider.notifier).state = section;
    case ItemLink(:final itemId):
      showItemDetails(context, itemId, announce: announce);
    case EventLink(:final eventId):
      showOpenEvent(context, eventId, announce: announce);
  }
}
