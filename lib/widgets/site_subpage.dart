import 'package:flutter/material.dart';

import '../theme.dart';


/// the width a page opened from a section keeps to on the site, in the middle
const sitePageWidth = 1200.0;

/// how a page opened from a section looks on the site: its bar is a heading on the page, not the dark bar of an app, and the page
/// keeps to the width of the site
ThemeData siteSubpageTheme(ThemeData base) => base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        iconTheme: IconThemeData(color: AppColors.gold),
        actionsIconTheme: IconThemeData(color: AppColors.gold),
        titleTextStyle: display(26, color: AppColors.text),
        shape: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {for (final platform in TargetPlatform.values) platform: const _SitePageTransitions()},
      ),
    );

/// a page opened on the site comes in softly and keeps to the width of the site, over the page it was opened from
class _SitePageTransitions extends PageTransitionsBuilder {
  const _SitePageTransitions();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (route.isFirst) return child;
    return FadeTransition(
      opacity: animation,
      child: ColoredBox(
        color: AppColors.bg,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: sitePageWidth), child: child),
        ),
      ),
    );
  }
}
