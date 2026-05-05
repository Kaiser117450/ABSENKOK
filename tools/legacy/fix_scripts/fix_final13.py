import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix unused local variable `appState`
content = content.replace(
    "final appState = ref.watch(appProvider);\n    final isKepalaGerai = appState.isKepalaGerai;",
    "final isKepalaGerai = ref.watch(appProvider).isKepalaGerai;"
)
content = content.replace(
    "final appState = ref.watch(appProvider);\n    if (_outlets.isEmpty) {",
    "if (_outlets.isEmpty) {"
)
content = content.replace(
    "final appState = ref.watch(appProvider);\n    setState(() {",
    "setState(() {"
)

# Remove `_totalEmployees` correctly this time by looking exactly for it
content = re.sub(r'\s*int _totalEmployees = 0;\s*', '\n  ', content)

# Fix the if condition missing braces
content = content.replace("if (ctx.mounted) Navigator.pop(ctx);", "if (ctx.mounted) { Navigator.pop(ctx); }")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
