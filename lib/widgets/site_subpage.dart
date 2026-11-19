import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// the width a page opened from a section keeps to on the site, in the middle
const sitePageWidth = 1200.0;

/// the width a page keeps to on a window of this width (as the app lays it out, after its zoom): the width of the site on a laptop,
/// and most of what the rail leaves on a larger window, so a page does not sit in the middle of a wide screen with room on both sides
double sitePageWidthFor(double windowWidth) => ((windowWidth - 84) * 0.92).clamp(sitePageWidth, 3000.0).toDouble();

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
          child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: sitePageWidthFor(MediaQuery.sizeOf(context).width)), child: child),
        ),
      ),
    );
  }
}
