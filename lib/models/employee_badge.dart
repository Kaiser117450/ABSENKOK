import 'package:flutter/material.dart';

enum BadgeBorderStyle {
  solid,
  gradient,
  glow;

  static BadgeBorderStyle fromString(String value) {
    switch (value.toLowerCase()) {
      case 'gradient':
        return BadgeBorderStyle.gradient;
      case 'glow':
        return BadgeBorderStyle.glow;
      default:
        return BadgeBorderStyle.solid;
    }
  }
}

class EmployeeBadge {
  final String id;
  final String name;
  final String? description;
  final String emoji;
  final String borderColor;
  final String? borderColor2;
  final String borderStyle;

  const EmployeeBadge({
    required this.id,
    required this.name,
    this.description,
    required this.emoji,
    required this.borderColor,
    this.borderColor2,
    required this.borderStyle,
  });

  factory EmployeeBadge.fromJson(Map<String, dynamic> json) => EmployeeBadge(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        emoji: json['emoji'] as String? ?? '',
        borderColor: json['border_color'] as String? ?? '#9CA3AF',
        borderColor2: json['border_color2'] as String?,
        borderStyle: json['border_style'] as String? ?? 'solid',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'emoji': emoji,
        'border_color': borderColor,
        'border_color2': borderColor2,
        'border_style': borderStyle,
      };

  /// Parse hex string like "#FFD700" to Color
  Color get color1 => _parseHex(borderColor);

  /// Parse second color for gradient (null if not set)
  Color? get color2 =>
      borderColor2 != null && borderColor2!.isNotEmpty ? _parseHex(borderColor2!) : null;

  /// Parse border style string to enum
  BadgeBorderStyle get style => BadgeBorderStyle.fromString(borderStyle);

  static Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    final normalized = cleaned.toUpperCase();
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$normalized', radix: 16);
      if (value != null) return Color(value);
    }
    if (cleaned.length == 8) {
      final value = int.tryParse(normalized, radix: 16);
      if (value != null) return Color(value);
    }
    return const Color(0xFF9CA3AF); // fallback gray
  }
}
