import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/api.dart';
import '../../state/settings.dart';
import '../../theme.dart';

OverlayEntry? _toast;
Timer? _toastTimer;

/// every short message the app shows.
///
/// not a snack bar: those live in a slot of the Scaffold that the drawer and
/// the bottom of the window both paint over, and the exit hint is shown with
/// the drawer open. the root overlay sits above all of it, and reading the
/// inset there keeps the message clear of the system navigation bar too
void showToast(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  hideToast();
  final entry = OverlayEntry(builder: (_) => _Toast(message: message));
  _toast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(duration, hideToast);
}

void hideToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  final entry = _toast;
  _toast = null;
  if (entry != null && entry.mounted) entry.remove();
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16 + MediaQuery.viewPaddingOf(context).bottom,
      // taps belong to whatever is underneath, the message is only a message
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 160),
          builder: (_, t, child) => Opacity(opacity: t, child: child),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> openUrl(BuildContext context, String url, {String failMessage = 'Could not open the page'}) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    showToast(context, failMessage);
  }
}

/// opens a wiki page in the in-app browser, using the wiki that matches the app language
Future<void> openWikiPage(BuildContext context, WidgetRef ref, String title) {
  final wiki = ref.read(wikiApiProvider);
  final s = ref.read(stringsProvider);
  return openUrl(context, wiki.pageUrl(title), failMessage: s.t('open_failed'));
}
