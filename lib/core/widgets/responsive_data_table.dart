import 'package:flutter/material.dart';

/// Wraps a fixed-width table [header] and scrollable [body] so the table
/// becomes horizontally scrollable instead of squeezing its columns or
/// overflowing when the available width drops below [minWidth].
///
/// On a screen wider than [minWidth], this renders exactly like the plain
/// `Column([header, Expanded(body)])` it replaces — no visual change, no
/// scrolling. Below it, the header and body scroll together (they share one
/// horizontal [SingleChildScrollView]) so columns keep their existing
/// layout, content, and actions untouched; only the viewport changes.
class ResponsiveDataTable extends StatelessWidget {
  const ResponsiveDataTable({
    super.key,
    required this.minWidth,
    required this.header,
    required this.body,
  });

  final double minWidth;
  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: constraints.maxHeight,
            child: Column(
              children: [
                header,
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}
