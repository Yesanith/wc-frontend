import 'package:flutter/material.dart';

import 'item_detail_screen.dart';

/// the item sheet every list opens. the name, icon and rarity the caller
/// already has are not needed any more, the sheet reads the item itself
void showItemSheet(
  BuildContext context, {
  required int id,
  String? name,
  String? icon,
  String? rarity,
  String? type,
  int count = 1,
}) =>
    showItemDetails(context, id);
