import 'package:flutter/material.dart';

/// Renders authoritative Indian Veg/Non-Veg dietary badge (SRS NFR-12).
/// Veg: Green square border with solid green dot.
/// Non-Veg: Red/Brown square border with solid red/brown dot.
class VegIndicator extends StatelessWidget {
  final bool isVeg;
  final double size;

  const VegIndicator({
    super.key,
    required this.isVeg,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isVeg ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final String label = isVeg ? 'Vegetarian' : 'Non-Vegetarian';

    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: Container(
            width: size * 0.45,
            height: size * 0.45,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

