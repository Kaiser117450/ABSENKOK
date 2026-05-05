import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the missing _totalEmployees
content = content.replace("int _todayBackup = 0; // Total backup hari ini\n", "int _todayBackup = 0; // Total backup hari ini\n  int _totalEmployees = 0;\n")

# Remove unused appState
content = re.sub(r'^\s*final appState = ref\.watch\(appProvider\);\s*\n', '', content, flags=re.MULTILINE)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
