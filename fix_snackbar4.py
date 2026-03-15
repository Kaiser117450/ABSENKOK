import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace block 3 (lines 1207-1215)
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\([\s\S]*?SnackBar\([\s\S]*?\'Gerai berhasil ditambahkan\'[\s\S]*?\)\s*,\s*\)\s*;\s*',
    r"AppToast.success(context, 'Gerai berhasil ditambahkan');\n                            ",
    content
)

# Replace block 4 (lines 1222-1230)
content = re.sub(
    r'ScaffoldMessenger\.of\(ctx\)\.showSnackBar\([\s\S]*?SnackBar\([\s\S]*?Text\(e\.toString\(\)\)[\s\S]*?\)\s*,\s*\)\s*;\s*',
    r"AppToast.error(ctx, e.toString());\n                            ",
    content
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
