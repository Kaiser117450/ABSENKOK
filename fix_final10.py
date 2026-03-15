import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I removed the declaration of _totalEmployees but it's used at line 104! Let's put it back.
content = content.replace("int _todayBackup = 0; // Total backup hari ini\n", "int _todayBackup = 0; // Total backup hari ini\n  int _totalEmployees = 0;\n")

# Same for appState
content = content.replace("final isKepalaGerai =", "final appState = ref.watch(appProvider);\n    final isKepalaGerai =")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
