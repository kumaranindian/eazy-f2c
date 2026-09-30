/// Centralized breakpoints for admin responsive layouts.
///
/// These match the thresholds [AdminDashboardPage] already uses for its
/// sidebar/drawer switch, so new responsive code stays consistent with the
/// app's existing admin-shell behavior instead of introducing a second,
/// competing breakpoint convention.
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  static const double tabletMin = 768;
  static const double desktopMin = 1200;

  static bool isMobile(double width) => width < tabletMin;

  static bool isTablet(double width) =>
      width >= tabletMin && width < desktopMin;

  static bool isDesktop(double width) => width >= desktopMin;
}
