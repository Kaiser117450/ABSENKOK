with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

imports = """import '../../widgets/app_card.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/app_toast.dart';
"""
content = content.replace("import '../../core/theme.dart';", f"import '../../core/theme.dart';\n{imports}")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
