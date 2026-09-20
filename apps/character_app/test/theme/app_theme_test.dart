import 'package:character_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la palette sombre reprend les couleurs de la maquette retenue', () {
    final theme = AppTheme.dark();

    expect(theme.scaffoldBackgroundColor, const Color(0xFF1C1712));
    expect(theme.colorScheme.primary, const Color(0xFFC9A227));
    expect(theme.colorScheme.onSurface, const Color(0xFFEDE3D0));
    expect(theme.brightness, Brightness.dark);
  });
}
