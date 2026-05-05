import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix unused fields properly
content = re.sub(r'int _todayBackup = 0; // Total backup hari ini\n\s*int _totalEmployees = 0;', 'int _todayBackup = 0; // Total backup hari ini', content)

# appState at 324 is within a method, let's just find and replace it
lines = content.split('\n')
new_lines = []
for i, line in enumerate(lines):
    if "final appState = ref.watch(appProvider);" in line:
        # if the next line is "if (_outlets.isEmpty) {", we don't need appState here
        if i + 1 < len(lines) and "if (_outlets.isEmpty) {" in lines[i+1]:
            continue
    if "if (ctx.mounted) Navigator.pop(ctx);" in line:
        line = line.replace("if (ctx.mounted) Navigator.pop(ctx);", "if (ctx.mounted) { Navigator.pop(ctx); }")
    new_lines.append(line)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write('\n'.join(new_lines))

