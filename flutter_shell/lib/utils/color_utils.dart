import 'package:flutter/material.dart';

class ColorUtils {
  /// Parse a `#RRGGBB` or `#AARRGGBB` hex string. Returns null if invalid.
  static Color? fromHex(String? hex) {
    if (hex == null) return null;
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final value = int.tryParse(s, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  /// Same as [fromHex] but falls back to the provided color on parse failure.
  static Color fromHexOr(String? hex, Color fallback) {
    return fromHex(hex) ?? fallback;
  }
}
