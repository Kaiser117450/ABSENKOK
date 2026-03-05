import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Imports
if "import '../../widgets/app_card.dart';" not in content:
    content = content.replace("import '../../core/theme.dart';",
        "import '../../core/theme.dart';\nimport '../../widgets/app_card.dart';\nimport '../../widgets/shimmer_skeleton.dart';\nimport '../../widgets/app_toast.dart';\n")

# 2. Methods
with open('shimmers.txt', 'r', encoding='utf-8') as f:
    shimmer_methods = f.read()

if "_buildListShimmer" not in content:
    idx = content.find("class _SheetField extends StatelessWidget {")
    if idx != -1:
        brace_idx = content.rfind("}", 0, idx)
        if brace_idx != -1:
            content = content[:brace_idx] + shimmer_methods + content[brace_idx:]

# 3. Replace Snackbars
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Gagal menyimpan: \$e'\),\s*backgroundColor:\s*AppColors\.danger,\s*\),\s*\);",
    r"AppToast.error(context, 'Gagal menyimpan: $e');",
    content
)
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(\s*content:\s*Text\('Pilih outlet terlebih dahulu'\),\s*backgroundColor:\s*Colors\.orange,\s*\),\s*\);",
    r"AppToast.error(context, 'Pilih outlet terlebih dahulu');",
    content
)

content = content.replace(
    "ScaffoldMessenger.of(context).showSnackBar(\n                                SnackBar(\n                                  content: const Text(\n                                      'Gerai berhasil ditambahkan'),\n                                  backgroundColor: AppColors.success,\n                                  behavior: SnackBarBehavior.floating,\n                                  shape: RoundedRectangleBorder(\n                                      borderRadius:\n                                          BorderRadius.circular(10)),\n                                ),\n                              );",
    "AppToast.success(context, 'Gerai berhasil ditambahkan');"
)

content = content.replace(
    "ScaffoldMessenger.of(ctx).showSnackBar(\n                                SnackBar(\n                                  content: Text(e.toString()),\n                                  backgroundColor: AppColors.danger,\n                                  behavior: SnackBarBehavior.floating,\n                                  shape: RoundedRectangleBorder(\n                                      borderRadius:\n                                          BorderRadius.circular(10)),\n                                ),\n                              );",
    "AppToast.error(ctx, e.toString());"
)

# 4. Containers -> AppCard
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

# Fix the missing parenthesis from the Employee list row card replacement
content = re.sub(
    r'margin: const EdgeInsets\.only\(bottom: 8\),\s*padding: EdgeInsets\.zero,\s*child: SizedBox\(\s*height: 70,\s*child: Row\(([\s\S]*?)\]\s*,\s*\)\s*,\s*\)\s*;\s*}',
    r'margin: const EdgeInsets.only(bottom: 8),\n      padding: EdgeInsets.zero,\n      child: SizedBox(\n        height: 70,\n        child: Row(\1],\n        ),\n      ),\n    );\n  }',
    content
)

# 5. Replace CircularProgressIndicators
content = content.replace(
    """SizedBox(
                          height: 100,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 3,
                            ),
                          ),
                        )""",
    """_buildDashboardShimmer()"""
)

content = content.replace(
    """const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              )""",
    """SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildListShimmer(),
                ),
              )"""
)

content = content.replace(
    """const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )""",
    """_buildListShimmer()"""
)

content = content.replace(
    """Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )""",
    """_buildListShimmer()"""
)

content = content.replace(
    """const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFD97706),
                    ),
                  )""",
    """const ShimmerSkeleton(width: 16, height: 16, borderRadius: 8)"""
)

content = content.replace(
    """const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Color(0xFF1A0A00), strokeWidth: 2.5),
                        )""",
    """const SizedBox(
                          width: 20,
                          height: 20,
                          child: ShimmerSkeleton(width: 20, height: 20, borderRadius: 10),
                        )"""
)

# Write back
with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
