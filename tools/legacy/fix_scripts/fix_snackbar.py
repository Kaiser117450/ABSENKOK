import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r') as f:
    content = f.read()

# Replace snackbars with AppToast
def replace_snackbar(match):
    full_match = match.group(0)
    snack_content = match.group(1)
    
    if "error" in full_match.lower() or "danger" in full_match.lower() or "red" in full_match.lower():
        return f"AppToast.error(context, {snack_content});"
    elif "info" in full_match.lower() or "blue" in full_match.lower():
        return f"AppToast.info(context, {snack_content});"
    else:
        return f"AppToast.success(context, {snack_content});"

content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(([^)]+)\)[^)]*\)\s*\);',
    replace_snackbar,
    content
)

# Also fix ones that might have more complex structures
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(\s*content:\s*Text\(([^)]+)\)[^)]*\)\s*\);',
    replace_snackbar,
    content
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w') as f:
    f.write(content)
