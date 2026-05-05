import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix `_totalEmployees`
content = content.replace("int _todayBackup = 0; // Total backup hari ini\n", "int _todayBackup = 0; // Total backup hari ini\n  int _totalEmployees = 0;\n")

# Remove unused `appState`
# There's still one around line 323 inside _buildHeader. Let's find it.
lines = content.split('\n')
new_lines = []
for i, line in enumerate(lines):
    if "final appState = ref.watch(appProvider);" in line:
        if i + 1 < len(lines) and "if (_outlets.isEmpty) {" in lines[i+1]:
            continue
    new_lines.append(line)

content = '\n'.join(new_lines)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
