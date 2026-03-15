import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# IMPORTS
if "import '../../widgets/app_card.dart';" not in content:
    content = content.replace("import '../../core/theme.dart';", 
        "import '../../core/theme.dart';\nimport '../../widgets/app_card.dart';\nimport '../../widgets/shimmer_skeleton.dart';\nimport '../../widgets/app_toast.dart';\n")

# CONTAINERS -> AppCard
content = re.sub(
    r'Container\(\s*margin: const EdgeInsets\.fromLTRB\(16, 0, 16, 12\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(14\),\s*border: Border\.all\(color: const Color\(0xFFFCD34D\)\.withOpacity\(0\.50\)\),\s*boxShadow: \[\s*BoxShadow\(\s*color: Colors\.black\.withOpacity\(0\.05\),\s*blurRadius: 8,\s*offset: const Offset\(0, 2\),\s*\),\s*\],\s*\),\s*child:',
    r'AppCard(\n      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),\n      padding: EdgeInsets.zero,\n      child:',
    content
)

content = re.sub(
    r'Container\(\s*height: 96,\s*padding: const EdgeInsets\.all\(14\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(16\),\s*boxShadow: \[\s*BoxShadow\(\s*color: accent\.withOpacity\(0\.08\),\s*blurRadius: 16,\s*offset: const Offset\(0, 4\),\s*\),\s*\],\s*\),\s*child:',
    r'AppCard(\n      padding: const EdgeInsets.all(14),\n      child: SizedBox(\n        height: 68,\n        child:',
    content
)

content = re.sub(
    r'Container\(\s*height: 70,\s*margin: const EdgeInsets\.only\(bottom: 8\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(14\),\s*boxShadow: \[\s*BoxShadow\(\s*color: Colors\.black\.withOpacity\(0\.04\),\s*blurRadius: 8,\s*offset: const Offset\(0, 2\),\s*\),\s*\],\s*\),\s*child: Row\(',
    r'AppCard(\n      margin: const EdgeInsets.only(bottom: 8),\n      padding: EdgeInsets.zero,\n      child: SizedBox(\n        height: 70,\n        child: Row(',
    content
)

# SNACKBARS
content = content.replace(
    "ScaffoldMessenger.of(context).showSnackBar(\n          SnackBar(\n            content: Text('Gagal menyimpan: $e'),\n            backgroundColor: AppColors.danger,\n          ),\n        );",
    "AppToast.error(context, 'Gagal menyimpan: $e');"
)
content = content.replace(
    "ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(\n          content: Text('Pilih outlet terlebih dahulu'),\n          backgroundColor: Colors.orange,\n        ),\n      );",
    "AppToast.error(context, 'Pilih outlet terlebih dahulu');"
)

content = content.replace(
    "ScaffoldMessenger.of(context).showSnackBar(\n                                SnackBar(\n                                  content: const Text(\n                                      'Gerai berhasil ditambahkan'),\n                                  backgroundColor: AppColors.success,\n                                  behavior: SnackBarBehavior.floating,\n                                  shape: RoundedRectangleBorder(\n                                      borderRadius:\n                                          BorderRadius.circular(10)),\n                                ),\n                              );",
    "AppToast.success(context, 'Gerai berhasil ditambahkan');"
)

content = content.replace(
    "ScaffoldMessenger.of(ctx).showSnackBar(\n                                SnackBar(\n                                  content: Text(e.toString()),\n                                  backgroundColor: AppColors.danger,\n                                  behavior: SnackBarBehavior.floating,\n                                  shape: RoundedRectangleBorder(\n                                      borderRadius:\n                                          BorderRadius.circular(10)),\n                                ),\n                              );",
    "AppToast.error(ctx, e.toString());"
)

# Write back
with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

