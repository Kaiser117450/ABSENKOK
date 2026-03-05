import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add _totalEmployees back!
content = content.replace("int _todayBackup = 0; // Total backup hari ini", "int _todayBackup = 0; // Total backup hari ini\n  int _totalEmployees = 0;")

# Fix appState usage
content = re.sub(r'\s*final appState = ref\.watch\(appProvider\);\n\s*(?!final isKepalaGerai)', '\n', content)

# Fix braces
content = content.replace("if (ctx.mounted) Navigator.pop(ctx);", "if (ctx.mounted) { Navigator.pop(ctx); }")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
