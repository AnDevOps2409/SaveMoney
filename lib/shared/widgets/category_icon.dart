import 'package:flutter/material.dart';
import 'package:savemoney/shared/models/models.dart';

/// Widget hiển thị icon danh mục theo style Money Lover
/// (rounded square với màu nền mờ)
class CategoryIcon extends StatelessWidget {
  final CategoryModel category;
  final double size;
  final double iconSize;
  final double radius;

  const CategoryIcon({
    super.key,
    required this.category,
    this.size = 44,
    this.iconSize = 22,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color.withAlpha(38),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(category.icon, color: category.color, size: iconSize),
    );
  }
}

/// Icon ví
class WalletIcon extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;

  const WalletIcon({
    super.key,
    required this.color,
    required this.icon,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
