import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r') as f:
    content = f.read()

# Add imports
if 'import \'../../widgets/app_card.dart\';' not in content:
    imports_to_add = """import '../../widgets/app_card.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/app_toast.dart';
"""
    content = content.replace("import '../../core/theme.dart';", f"import '../../core/theme.dart';\n{imports_to_add}")

# Replace snackbars with AppToast
content = re.sub(r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(\'([^\']+)\'\)(?:,\s*backgroundColor:\s*([^,]+))?.*?\)\s*\);',
                 lambda m: f"AppToast.{'error' if 'error' in (m.group(2) or '').lower() or 'red' in (m.group(2) or '').lower() else 'success'}(context, '{m.group(1)}');",
                 content, flags=re.DOTALL)

# Let's write back the changes
with open('lib/screens/admin/admin_dashboard_screen.dart', 'w') as f:
    f.write(content)

