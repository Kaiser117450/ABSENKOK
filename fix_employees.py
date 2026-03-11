import re

with open('lib/screens/admin/admin_employees_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
imports = """import '../../widgets/app_card.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_toast.dart';
"""
if "import '../../widgets/app_card.dart';" not in content:
    content = content.replace("import '../../core/theme.dart';", f"import '../../core/theme.dart';\n{imports}")

# 2. Add Shimmer Methods right before the end of _AdminEmployeesScreenState
shimmer_methods = """
  Widget _buildEmployeeListShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: 5,
      itemBuilder: (context, index) => const AppCard(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 80,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ShimmerSkeleton(width: 48, height: 48, borderRadius: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerSkeleton(width: 150, height: 16, borderRadius: 4),
                      SizedBox(height: 8),
                      ShimmerSkeleton(width: 100, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                ShimmerSkeleton(width: 24, height: 24, borderRadius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
"""

if "_buildEmployeeListShimmer" not in content:
    idx = content.find("void _showEmployeeForm")
    if idx != -1:
        content = content[:idx] + shimmer_methods + "\n  " + content[idx:]
    else:
        print("Could not find _showEmployeeForm")

# 3. Replace Snackbars
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(\'Gerai belum dipilih\'\)[^)]*\)\s*\);',
    r"AppToast.error(context, 'Gerai belum dipilih');",
    content
)

content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(\'Pilih outlet terlebih dahulu\'\)[^)]*\)\s*\);',
    r"AppToast.error(context, 'Pilih outlet terlebih dahulu');",
    content
)

# And inside the dialogs / form submits:
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?(?:backgroundColor:\s*AppColors\.success[^;]+?|\));',
    r"AppToast.success(context, \1);",
    content
)
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?danger[^;]+?\));',
    r"AppToast.error(context, \1);",
    content
)
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?Colors\.red[^;]+?\));',
    r"AppToast.error(context, \1);",
    content
)

# 4. Replace Containers with AppCard for the employee list items
content = re.sub(
    r'Container\(\s*margin: const EdgeInsets\.only\(bottom: 12\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(16\),\s*boxShadow: \[\s*BoxShadow\(\s*color: Colors\.black\.withOpacity\([^)]+\),\s*blurRadius: [^,]+,\s*offset: [^\]]+,\s*\),\s*\],\s*\),\s*child:',
    r'AppCard(\n      margin: const EdgeInsets.only(bottom: 12),\n      padding: EdgeInsets.zero,\n      child:',
    content
)

# 5. Replace Empty States
content = re.sub(
    r'Center\(\s*child: Column\(\s*mainAxisAlignment: MainAxisAlignment\.center,\s*children: \[\s*Icon\(\s*Icons\.people_outline,\s*size: 64,\s*color: Colors\.grey\[400\],\s*\),\s*const SizedBox\(height: 16\),\s*Text\(\s*\'Belum ada karyawan\',\s*style: TextStyle\(\s*color: Colors\.grey\[600\],\s*fontSize: 16,\s*\),\s*\),\s*\],\s*\),\s*\)',
    r"AppEmptyState(\n            icon: Icons.people_outline,\n            heading: 'Belum Ada Karyawan',\n            subtext: 'Tambahkan karyawan untuk memulai',\n          )",
    content
)

# Replace remaining direct CircularProgressIndicator
content = content.replace(
    "const Center(child: CircularProgressIndicator())",
    "_buildEmployeeListShimmer()"
)

with open('lib/screens/admin/admin_employees_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

