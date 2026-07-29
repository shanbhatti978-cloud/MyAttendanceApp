import 'package:flutter/material.dart';

/// Small helper so grids/lists adapt between phones and tablets.
/// Desktop/laptop breakpoints are intentionally not handled — this app
/// targets Android phones and tablets only, by explicit request.
class Responsive {
  /// True once the shortest side is wide enough to be a tablet (roughly
  /// a 7"+ device in portrait or a phone in landscape on a large screen).
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.shortestSide >= 600;

  /// Column count for stat/KPI grids: 2 on phones, 3 on tablets.
  static int statGridColumns(BuildContext context) => isTablet(context) ? 3 : 2;

  /// Column count for list-like content shown as cards (Employee list,
  /// report rows): 1 on phones, 2 on tablets, so a tablet's extra width
  /// is put to use instead of leaving a long single narrow column.
  static int listGridColumns(BuildContext context) => isTablet(context) ? 2 : 1;

  /// Caps content width on very wide tablets so cards don't stretch
  /// uncomfortably edge-to-edge; centers the content instead.
  static double maxContentWidth(BuildContext context) => isTablet(context) ? 900 : double.infinity;
}
