import 'package:flutter/material.dart';

/// Lays out a row of stat cards that wraps onto additional rows instead of
/// squeezing every card into one line when the available width is narrow.
///
/// On a screen wide enough to fit all cards on one line, this renders the
/// same as the [Row] of [Expanded] cards it replaces: each card still takes
/// an equal share of the full width. Below that, cards wrap onto further
/// rows so nothing gets clipped or illegibly squeezed on mobile.
class ResponsiveStatCardsRow extends StatelessWidget {
  const ResponsiveStatCardsRow({
    super.key,
    required this.cards,
    this.minCardWidth = 150,
    this.spacing = 12,
  });

  final List<Widget> cards;
  final double minCardWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = ((maxWidth + spacing) / (minCardWidth + spacing))
            .floor()
            .clamp(1, cards.length);
        final cardWidth = (maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}
