import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';

class WarehouseFormSection extends StatelessWidget {
  const WarehouseFormSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ColorSkin.title,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ColorSkin.subtitle,
            ),
          ),
        ],
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}
