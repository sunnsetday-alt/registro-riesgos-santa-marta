import 'package:flutter/material.dart';

import '../../core/constants/category_icons.dart';
import '../../core/theme/app_colors.dart';

class Category {
  final int id;
  final String code;
  final String name;
  final String? description;
  final String icon;
  final String colorHex;
  final double priorityWeight;
  final List<String> keywords;
  final bool isActive;
  final int sortOrder;

  const Category({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.icon,
    required this.colorHex,
    required this.priorityWeight,
    required this.keywords,
    required this.isActive,
    required this.sortOrder,
  });

  Color get color => AppColors.fromHex(colorHex);
  IconData get iconData => CategoryIcons.of(icon);

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: (m['id'] as num).toInt(),
        code: m['code'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        icon: (m['icon'] as String?) ?? 'report',
        colorHex: (m['color'] as String?) ?? '#0077B6',
        priorityWeight: (m['priority_weight'] as num?)?.toDouble() ?? 1.0,
        keywords: ((m['keywords'] as List?) ?? const []).map((e) => e.toString()).toList(),
        isActive: (m['is_active'] as bool?) ?? true,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toUpsertMap() => {
        'code': code,
        'name': name,
        'description': description,
        'icon': icon,
        'color': colorHex,
        'priority_weight': priorityWeight,
        'keywords': keywords,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}
