import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix unused local variable `appState`
content = content.replace("final appState = ref.watch(appProvider);", "")
content = content.replace("final isKepalaGerai = .isKepalaGerai;", "final isKepalaGerai = ref.watch(appProvider).isKepalaGerai;")

# Fix unused field `_totalEmployees`
content = content.replace("int _totalEmployees = 0;\n", "")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
