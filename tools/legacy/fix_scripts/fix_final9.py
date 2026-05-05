import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("int _totalEmployees = 0;\n", "")
content = re.sub(r'final appState = ref\.watch\(appProvider\);\s*', '', content)

# Fix the if statement braces
content = content.replace("if (ctx.mounted) Navigator.pop(ctx);", "if (ctx.mounted) { Navigator.pop(ctx); }")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
