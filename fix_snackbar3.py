import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace block 1 (lines 289-293)
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(\'Gagal menyimpan: \$e\'\),\s*backgroundColor:\s*AppColors\.danger,\s*\),\s*\);',
    r"AppToast.error(context, 'Gagal menyimpan: $e');",
    content, flags=re.MULTILINE
)

# Replace block 2 (lines 823-827)
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(\s*content:\s*Text\(\'Pilih outlet terlebih dahulu\'\),\s*backgroundColor:\s*Colors\.orange,\s*\),\s*\);',
    r"AppToast.error(context, 'Pilih outlet terlebih dahulu');",
    content, flags=re.MULTILINE
)

# Replace block 3 (lines 1217-1224)
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*const Text\(\s*\'Gerai berhasil ditambahkan\'\),\s*backgroundColor:\s*AppColors\.success,\s*behavior:\s*SnackBarBehavior\.floating,\s*shape:\s*RoundedRectangleBorder\(\s*borderRadius:\s*BorderRadius\.circular\(10\),\s*\),\s*\),\s*\);',
    r"AppToast.success(context, 'Gerai berhasil ditambahkan');",
    content, flags=re.MULTILINE
)

# Replace block 4 (lines 1232-1240)
content = re.sub(
    r'ScaffoldMessenger\.of\(ctx\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(e\.toString\(\)\),\s*backgroundColor:\s*AppColors\.danger,\s*behavior:\s*SnackBarBehavior\.floating,\s*shape:\s*RoundedRectangleBorder\(\s*borderRadius:\s*BorderRadius\.circular\(10\),\s*\),\s*\),\s*\);',
    r"AppToast.error(ctx, e.toString());",
    content, flags=re.MULTILINE
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
