import 'package:web/web.dart' as web;

/// takes the query (?error=…) out of the address the page is at, keeping the path and the page after the #, without
/// loading anything again or adding a step to go back to
void dropAddressQuery() {
  final location = web.window.location;
  if (location.search.isEmpty) return;
  web.window.history.replaceState(null, '', '${location.pathname}${location.hash}');
}
