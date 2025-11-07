import 'package:flutter/material.dart';

// Kelas ini mendefinisikan warna kustom yang ingin kita tambahkan ke tema.
class AppTheme extends ThemeExtension<AppTheme> {
  const AppTheme({
    required this.cardGradientStart,
    required this.cardGradientEnd,
  });

  final Color cardGradientStart;
  final Color cardGradientEnd;

  // Metode 'copyWith' diperlukan untuk memungkinkan tema ditimpa sebagian.
  @override
  AppTheme copyWith({
    Color? cardGradientStart,
    Color? cardGradientEnd,
  }) {
    return AppTheme(
      cardGradientStart: cardGradientStart ?? this.cardGradientStart,
      cardGradientEnd: cardGradientEnd ?? this.cardGradientEnd,
    );
  }

  // Metode 'lerp' (Linear Interpolation) diperlukan untuk transisi tema yang mulus.
  @override
  AppTheme lerp(ThemeExtension<AppTheme>? other, double t) {
    if (other is! AppTheme) {
      return this;
    }
    return AppTheme(
      cardGradientStart: Color.lerp(cardGradientStart, other.cardGradientStart, t)!,
      cardGradientEnd: Color.lerp(cardGradientEnd, other.cardGradientEnd, t)!,
    );
  }
}