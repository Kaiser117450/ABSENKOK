# Phase 21: Badge Color Picker - Research

**Researched:** 2026-03-18
**Domain:** Flutter color picker UI, badge management enhancement
**Confidence:** HIGH

## Summary

Phase 21 replaces the current hex-text-input color fields in the badge management form with a visual color picker. The existing badge system is fully functional -- `badge_management_screen.dart` has a `_showBadgeForm()` dialog with `TextField` widgets for `color1Ctrl` (hex) and `color2Ctrl` (hex). The task is purely UI: swap these TextFields for a visual color picker widget, and ensure the `BadgeAvatar` preview updates in real time as colors change.

The existing architecture already supports live preview via `StatefulBuilder` + `setDialogState(() {})` on every field change. The `EmployeeBadge` model already parses hex strings (`#RRGGBB`) to `Color` objects. The color picker just needs to produce hex strings that feed into the existing `borderColor`/`borderColor2` fields.

**Primary recommendation:** Use `flutter_colorpicker` (v1.1.0) -- it is lightweight, provides an HSV color wheel out of the box, requires zero configuration, and has been stable for 2+ years with 336K+ downloads. The simpler API is a better fit than `flex_color_picker` for this use case (just picking two colors).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BADGE-01 | Admin can pick badge border color using a visual color wheel/grid instead of typing hex | Replace `color1Ctrl` TextField with `ColorPicker` widget from `flutter_colorpicker`; use HSV wheel mode |
| BADGE-02 | Admin can pick both color1 and color2 for gradient badge styles | Two separate color picker triggers (tappable color swatch), each opening the same picker dialog but writing to `color1Ctrl` or `color2Ctrl` respectively |
| BADGE-03 | Admin sees a live badge preview while selecting colors | Already implemented via `StatefulBuilder` + `setDialogState`; just call `setDialogState` from the `onColorChanged` callback |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_colorpicker | 1.1.0 | HSV/Material color wheel picker | 336K+ downloads, stable 2+ years, simple API, lightweight |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| flutter_colorpicker | flex_color_picker 3.8.0 | More features (tonal palettes, recent colors, opacity) but heavier; overkill for picking 2 badge colors |
| flutter_colorpicker | Custom HSV wheel | Don't hand-roll -- color math and touch handling are complex |

**Installation:**
```bash
cd "C:\Users\HYPE R Series\Desktop\projekan\absensi apk\absensi_enakko_flutter"
C:\flutter\bin\flutter.bat pub add flutter_colorpicker
```

## Architecture Patterns

### Current Badge Form Flow (what exists)
```
badge_management_screen.dart
  _showBadgeForm()
    -> AlertDialog with StatefulBuilder
    -> TextField(controller: color1Ctrl)  <-- REPLACE THIS
    -> TextField(controller: color2Ctrl)  <-- REPLACE THIS
    -> BadgeAvatar(badge: EmployeeBadge(...))  <-- ALREADY LIVE-UPDATES
    -> onChanged: (_) => setDialogState(() {})  <-- ALREADY TRIGGERS REBUILD
```

### Target Architecture (what to build)
```
badge_management_screen.dart
  _showBadgeForm()
    -> AlertDialog with StatefulBuilder
    -> _ColorPickerField(
         label: "Warna Utama",
         currentColor: _parseHex(color1Ctrl.text),
         onColorSelected: (color) {
           color1Ctrl.text = _colorToHex(color);
           setDialogState(() {});
         },
       )
    -> _ColorPickerField(  // only visible when style == gradient
         label: "Warna Gradient",
         currentColor: _parseHex(color2Ctrl.text),
         onColorSelected: (color) { ... },
       )
    -> BadgeAvatar(...)  <-- UNCHANGED, already live-updates
```

### Pattern 1: Color Picker Field Widget
**What:** A tappable row showing current color swatch + label, opens color picker dialog on tap
**When to use:** Replacing hex TextField inputs in badge form
**Example:**
```dart
// Tappable color field that opens picker dialog
Widget _buildColorPickerField({
  required String label,
  required Color currentColor,
  required ValueChanged<Color> onColorSelected,
  required StateSetter setDialogState,
}) {
  return InkWell(
    onTap: () {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(label),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                onColorSelected(color);
                setDialogState(() {});  // live preview update
              },
              enableAlpha: false,  // no transparency needed for badge borders
              hexInputBar: true,   // optional: still allow hex input as fallback
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: currentColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '#${currentColor.value.toRadixString(16).substring(2).toUpperCase()}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    ),
  );
}
```

### Pattern 2: Hex Color Conversion
**What:** Convert between Color objects and hex strings for storage
**Example:**
```dart
// Color -> hex string for storage
String _colorToHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
}

// Hex string -> Color (already exists in EmployeeBadge._parseHex)
// Reuse EmployeeBadge._parseHex or extract as static utility
```

### Pattern 3: Conditional Color2 Field
**What:** Only show color2 picker when border style is 'gradient'
**Example:**
```dart
if (selectedStyle == 'gradient') ...[
  const SizedBox(height: 12),
  _buildColorPickerField(
    label: 'Warna Gradient',
    currentColor: _parseColor(color2Ctrl.text, fallback: Colors.orange),
    onColorSelected: (color) {
      color2Ctrl.text = _colorToHex(color);
    },
    setDialogState: setDialogState,
  ),
],
```

### Anti-Patterns to Avoid
- **Nested dialogs stacking:** The badge form is already an AlertDialog. Opening a color picker as another AlertDialog creates a dialog-on-dialog. This is acceptable in Flutter (common pattern), but ensure proper `Navigator.pop` handling so both can dismiss correctly.
- **Alpha channel confusion:** Badge colors are stored as `#RRGGBB` (6 chars). Set `enableAlpha: false` on the picker to avoid 8-char hex values with transparency.
- **Forgetting setDialogState:** The live preview depends on calling `setDialogState(() {})` after color changes. Must be called in `onColorChanged`, not just on dialog dismiss.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Color wheel/HSV picker | Custom GestureDetector + Canvas + color math | flutter_colorpicker ColorPicker | Touch handling, HSV math, accessibility are complex |
| Color hex parsing | New parsing utility | EmployeeBadge._parseHex (already exists) | Avoid duplication, handles edge cases |

**Key insight:** The existing codebase already has hex-to-Color parsing in `EmployeeBadge._parseHex`. The only new code needed is Color-to-hex (trivial one-liner) and the picker integration UI.

## Common Pitfalls

### Pitfall 1: Dialog-on-Dialog Navigation
**What goes wrong:** Color picker dialog opens on top of badge form dialog. If not handled carefully, pressing back can close the wrong dialog.
**Why it happens:** Nested Navigator.pop calls.
**How to avoid:** The color picker dialog should have its own explicit close button. Use `Navigator.pop(ctx)` with the correct context from the builder.
**Warning signs:** Tapping outside dismisses both dialogs at once.

### Pitfall 2: Alpha Channel in Hex Storage
**What goes wrong:** Color picker returns `#AARRGGBB` (8 chars) but database stores `#RRGGBB` (6 chars).
**Why it happens:** flutter_colorpicker includes alpha by default.
**How to avoid:** Set `enableAlpha: false` on ColorPicker. When converting Color to hex, always take last 6 chars: `color.value.toRadixString(16).substring(2)`.
**Warning signs:** Colors look correct in preview but wrong after save/reload.

### Pitfall 3: Color2 Not Cleared When Switching Styles
**What goes wrong:** Admin picks gradient colors, then switches to "solid" style. color2 value remains in the controller and gets saved.
**Why it happens:** The existing form already has this issue (not a regression). But color picker makes it more visible since users interact more with colors.
**How to avoid:** Clear `color2Ctrl.text` when style changes away from 'gradient', or only send color2 to the API when style is 'gradient'.
**Warning signs:** Non-gradient badges have a stale color2 in the database.

### Pitfall 4: Existing StatefulBuilder Pattern
**What goes wrong:** The `setDialogState` from `StatefulBuilder` must be the one called -- not `setState` from the parent screen.
**Why it happens:** Confusing which state setter to use in nested builders.
**How to avoid:** Pass `setDialogState` explicitly to helper methods. The existing code already does this correctly -- follow the same pattern.

## Code Examples

### Existing Code to Modify
**File:** `lib/screens/admin/badge_management_screen.dart`
**Method:** `_showBadgeForm()` (lines 70-241)
**What changes:**
1. Replace `TextField(controller: color1Ctrl, ...)` (lines 129-138) with color picker field
2. Replace `TextField(controller: color2Ctrl, ...)` (lines 140-149) with conditional color picker field
3. Add helper method `_buildColorPickerField` or inline `_ColorPickerTile` widget

### Minimal Integration
```dart
// In _showBadgeForm(), replace color1 TextField with:
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

// Helper to parse hex safely (reuse existing logic)
Color _safeParseHex(String hex) {
  final cleaned = hex.replaceAll('#', '').trim().toUpperCase();
  if (cleaned.length == 6) {
    final v = int.tryParse('FF$cleaned', radix: 16);
    if (v != null) return Color(v);
  }
  return const Color(0xFF9CA3AF);
}

// Replace color TextField with tappable swatch
GestureDetector(
  onTap: () async {
    Color tempColor = _safeParseHex(color1Ctrl.text);
    await showDialog(
      context: ctx,
      builder: (pickerCtx) => AlertDialog(
        title: const Text('Pilih Warna Utama'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: tempColor,
            onColorChanged: (c) {
              tempColor = c;
              // Update controller and trigger preview rebuild
              color1Ctrl.text = '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
              setDialogState(() {});
            },
            enableAlpha: false,
            hexInputBar: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(pickerCtx),
            child: const Text('Pilih'),
          ),
        ],
      ),
    );
  },
  child: InputDecorator(
    decoration: const InputDecoration(
      labelText: 'Warna Utama',
      border: OutlineInputBorder(),
    ),
    child: Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: _safeParseHex(color1Ctrl.text),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(width: 12),
        Text(color1Ctrl.text.isEmpty ? '#FFD700' : color1Ctrl.text),
      ],
    ),
  ),
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hex text input | Visual color picker with wheel | This phase | UX improvement -- no more guessing hex codes |
| Type color codes manually | Tap swatch, see wheel, pick visually | This phase | Non-technical admins can use it |

## Open Questions

1. **Live preview during picker interaction vs on-dismiss**
   - What we know: `onColorChanged` fires on every touch move on the wheel. Calling `setDialogState` on every change gives true real-time preview but may cause frequent rebuilds of the parent dialog.
   - What's unclear: Performance impact on lower-end devices.
   - Recommendation: Use `onColorChanged` for live preview (it is lightweight -- `BadgeAvatar` is just a `CustomPaint`). If janky, debounce with a simple flag.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | pubspec.yaml (dev_dependencies) |
| Quick run command | `C:\flutter\bin\flutter.bat test --name "badge"` |
| Full suite command | `C:\flutter\bin\flutter.bat test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BADGE-01 | Color picker widget renders and produces Color values | widget test | `C:\flutter\bin\flutter.bat test test/widgets/color_picker_field_test.dart -x` | No - Wave 0 |
| BADGE-02 | Color2 field appears only when style is gradient | widget test | `C:\flutter\bin\flutter.bat test test/widgets/color_picker_field_test.dart -x` | No - Wave 0 |
| BADGE-03 | Badge preview updates when color changes | widget test | `C:\flutter\bin\flutter.bat test test/screens/badge_form_test.dart -x` | No - Wave 0 |

### Sampling Rate
- **Per task commit:** `C:\flutter\bin\flutter.bat test --name "badge"`
- **Per wave merge:** `C:\flutter\bin\flutter.bat test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/widgets/color_picker_field_test.dart` -- covers BADGE-01, BADGE-02
- [ ] `test/screens/badge_form_test.dart` -- covers BADGE-03 (preview updates)
- [ ] Note: Widget tests for dialogs with `flutter_colorpicker` may require `pumpAndSettle` and finding the picker by type

## Sources

### Primary (HIGH confidence)
- [pub.dev/packages/flutter_colorpicker](https://pub.dev/packages/flutter_colorpicker) - v1.1.0, API, features
- [pub.dev/packages/flex_color_picker](https://pub.dev/packages/flex_color_picker) - v3.8.0, compared as alternative

### Secondary (MEDIUM confidence)
- [fluttergems.dev/color-picker-utilities](https://fluttergems.dev/packages/flutter_colorpicker/) - ecosystem comparison
- Existing codebase: `badge_management_screen.dart`, `employee_badge.dart`, `badge_avatar.dart` - current architecture

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - flutter_colorpicker is stable, well-documented, widely used
- Architecture: HIGH - existing badge form architecture is clear, modification points identified precisely
- Pitfalls: HIGH - pitfalls are based on direct code analysis of existing form

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (stable domain, no rapid changes expected)
