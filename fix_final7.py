import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix unused fields and variables
content = re.sub(r'\n\s*int _totalEmployees = 0;\n', '\n', content)
content = re.sub(r'\s*final appState = ref\.watch\(appProvider\);\s*', '\n', content)

# Fix withOpacity => withValues(alpha: X)
content = re.sub(r'\.withOpacity\(([^)]+)\)', r'.withValues(alpha: \1)', content)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
