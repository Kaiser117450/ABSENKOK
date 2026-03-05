import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern 1
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(content:\s*Text\(\'Tidak dapat memperbarui token: outlet tidak dipilih\'\)\),\s*\);',
    r"AppToast.error(context, 'Tidak dapat memperbarui token: outlet tidak dipilih');",
    content, flags=re.MULTILINE
)

# Pattern 2
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(\'Token berhasil diperbarui: \$newToken\'\),\s*backgroundColor:\s*AppColors\.success,\s*\),\s*\);',
    r"AppToast.success(context, 'Token berhasil diperbarui: $newToken');",
    content, flags=re.MULTILINE
)

# Pattern 3
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(\s*content:\s*Text\(\'Gerai belum dipilih\'\)\),\s*\);',
    r"AppToast.error(context, 'Gerai belum dipilih');",
    content, flags=re.MULTILINE
)

# Pattern 4
content = re.sub(
    r'ScaffoldMessenger\.of\(ctx\)\.showSnackBar\(\s*const SnackBar\(\s*content:\s*Text\(\'Gerai belum dipilih\'\)\),\s*\);',
    r"AppToast.error(ctx, 'Gerai belum dipilih');",
    content, flags=re.MULTILINE
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
