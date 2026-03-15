import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I deleted _totalEmployees but it is still used at line 104! Let's put it back properly.
content = content.replace("int _todayBackup = 0; // Total backup hari ini", "int _todayBackup = 0; // Total backup hari ini\n  int _totalEmployees = 0;")

# Remove the unused appState at 323
content = re.sub(r'^\s*final appState = ref\.watch\(appProvider\);\s*\n', '', content, flags=re.MULTILINE)

# Fix braces at 1195
content = content.replace("if (ctx.mounted) Navigator.pop(ctx);", "if (ctx.mounted) { Navigator.pop(ctx); }")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
