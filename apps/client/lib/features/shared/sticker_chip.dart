import 'package:flutter/material.dart';

import '../../app.dart';

/// A hand-set label sticker: pill shape, thick ink border, tinted fill.
/// The visual signature of Direction A for any status or tag.
class StickerChip extends StatelessWidget {
  const StickerChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.visualDensity = VisualDensity.compact,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VisualDensity visualDensity;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = dark ? PantryPalTheme.darkLine : PantryPalTheme.ink;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon == null ? 10 : 8,
        vertical: visualDensity == VisualDensity.compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.28 : 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 0.02,
            ),
          ),
        ],
      ),
    );
  }
}
