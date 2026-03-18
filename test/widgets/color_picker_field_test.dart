import 'package:absensi_enakko_flutter/screens/admin/badge_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BadgeColorPickerField', () {
    Future<void> pumpColorPickerField(
      WidgetTester tester, {
      required Color currentColor,
      required ValueChanged<Color> onColorSelected,
      String label = 'Warna Utama',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BadgeColorPickerField(
                label: label,
                currentColor: currentColor,
                onColorSelected: onColorSelected,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('color swatch shows current color', (tester) async {
      await pumpColorPickerField(
        tester,
        currentColor: const Color(0xFFFFD700),
        onColorSelected: (_) {},
      );

      expect(find.text('#FFD700'), findsOneWidget);

      final swatch = tester.widget<Container>(
        find.byKey(const ValueKey('badge-color-picker-swatch-Warna Utama')),
      );
      final decoration = swatch.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFD700));
    });

    testWidgets('tapping swatch opens color picker dialog', (tester) async {
      await pumpColorPickerField(
        tester,
        currentColor: const Color(0xFFFFD700),
        onColorSelected: (_) {},
      );

      await tester.tap(
        find.byKey(const ValueKey('badge-color-picker-field-Warna Utama')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ColorPicker), findsOneWidget);
      expect(find.text('Warna Utama'), findsAtLeastNWidgets(1));
    });

    testWidgets('color2 field hidden when style is not gradient', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _BadgeColorFieldVisibilityHarness(),
          ),
        ),
      );

      expect(find.text('Warna Gradient'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('toggle-badge-style')));
      await tester.pumpAndSettle();

      expect(find.text('Warna Gradient'), findsOneWidget);
    });

    testWidgets('picking a color updates the preview swatch in real time',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _BadgeColorPickerRealtimeHarness(),
          ),
        ),
      );

      expect(find.text('#FFD700'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('badge-color-picker-field-Warna Utama')),
      );
      await tester.pumpAndSettle();

      final picker = tester.widget<ColorPicker>(find.byType(ColorPicker));
      picker.onColorChanged(const Color(0xFF00FF7F));
      await tester.pumpAndSettle();

      final hexLabel = tester.widget<Text>(
        find.byKey(const ValueKey('badge-color-picker-hex-Warna Utama')),
      );
      expect(hexLabel.data, '#00FF7F');

      final swatch = tester.widget<Container>(
        find.byKey(const ValueKey('badge-color-picker-swatch-Warna Utama')),
      );
      final decoration = swatch.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF00FF7F));
    });
  });
}

class _BadgeColorFieldVisibilityHarness extends StatefulWidget {
  const _BadgeColorFieldVisibilityHarness();

  @override
  State<_BadgeColorFieldVisibilityHarness> createState() =>
      _BadgeColorFieldVisibilityHarnessState();
}

class _BadgeColorFieldVisibilityHarnessState
    extends State<_BadgeColorFieldVisibilityHarness> {
  String selectedStyle = 'solid';
  Color color1 = const Color(0xFFFFD700);
  Color color2 = const Color(0xFFFFA500);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BadgeColorPickerField(
          label: 'Warna Utama',
          currentColor: color1,
          onColorSelected: (color) => setState(() => color1 = color),
        ),
        if (selectedStyle == 'gradient') ...[
          const SizedBox(height: 12),
          BadgeColorPickerField(
            label: 'Warna Gradient',
            currentColor: color2,
            onColorSelected: (color) => setState(() => color2 = color),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('toggle-badge-style'),
          onPressed: () {
            setState(() {
              selectedStyle =
                  selectedStyle == 'gradient' ? 'solid' : 'gradient';
            });
          },
          child: Text(selectedStyle),
        ),
      ],
    );
  }
}

class _BadgeColorPickerRealtimeHarness extends StatefulWidget {
  const _BadgeColorPickerRealtimeHarness();

  @override
  State<_BadgeColorPickerRealtimeHarness> createState() =>
      _BadgeColorPickerRealtimeHarnessState();
}

class _BadgeColorPickerRealtimeHarnessState
    extends State<_BadgeColorPickerRealtimeHarness> {
  Color selectedColor = const Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return BadgeColorPickerField(
      label: 'Warna Utama',
      currentColor: selectedColor,
      onColorSelected: (color) => setState(() => selectedColor = color),
    );
  }
}
