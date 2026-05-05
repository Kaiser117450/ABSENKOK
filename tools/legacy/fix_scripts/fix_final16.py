import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# _totalEmployees is still used in line 104? Let's check what line 104 is.
# Actually let's just add it back.
content = content.replace("int _todayBackup = 0; // Total backup hari ini\n", "int _todayBackup = 0; // Total backup hari ini\n  int _totalEmployees = 0;\n")

# appState in 323
lines = content.split('\n')
new_lines = []
for i, line in enumerate(lines):
    if "final appState = ref.watch(appProvider);" in line:
        # Check if the next non-empty line has 'if (_outlets.isEmpty) {'
        j = i + 1
        while j < len(lines) and lines[j].strip() == '':
            j += 1
        if j < len(lines) and "setState(() {" in lines[j]:
            continue
            
    if "if (ctx.mounted) Navigator.pop(ctx);" in line:
        line = line.replace("if (ctx.mounted) Navigator.pop(ctx);", "if (ctx.mounted) { Navigator.pop(ctx); }")
    
    new_lines.append(line)

content = '\n'.join(new_lines)
with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
