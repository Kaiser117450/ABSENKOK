import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Let's cleanly inject the methods just before `class _SheetField extends StatelessWidget {`
shimmer_methods = """
  Widget _buildListShimmer() {
    return Column(
      children: List.generate(
        3,
        (index) => AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: ShimmerSkeleton(width: 40, height: 40, borderRadius: 20),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerSkeleton(width: 120, height: 14, borderRadius: 4),
                      SizedBox(height: 8),
                      ShimmerSkeleton(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: ShimmerSkeleton(width: 60, height: 24, borderRadius: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardShimmer() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricShimmer()),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricShimmer()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMetricShimmer()),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricShimmer()),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricShimmer() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 68,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerSkeleton(width: 32, height: 32, borderRadius: 8),
                ShimmerSkeleton(width: 48, height: 24, borderRadius: 12),
              ],
            ),
            const ShimmerSkeleton(width: 80, height: 12, borderRadius: 4),
          ],
        ),
      ),
    );
  }
"""

if "_buildListShimmer" not in content:
    idx = content.find("class _SheetField extends StatelessWidget {")
    if idx != -1:
        # Find the previous closing brace `}` 
        prev_brace = content.rfind("}", 0, idx)
        if prev_brace != -1:
            content = content[:prev_brace] + shimmer_methods + content[prev_brace:]

# Imports
if "import '../../widgets/app_card.dart';" not in content:
    content = content.replace("import '../../core/theme.dart';", "import '../../core/theme.dart';\nimport '../../widgets/app_card.dart';\nimport '../../widgets/shimmer_skeleton.dart';\nimport '../../widgets/app_toast.dart';\n")

# Replace Snackbars using regex
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(\'Gagal menyimpan: \$e\'\),\s*backgroundColor:\s*AppColors\.danger,\s*\),\s*\);',
    r"AppToast.error(context, 'Gagal menyimpan: $e');",
    content
)

content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(\s*content:\s*Text\(\'Pilih outlet terlebih dahulu\'\),\s*backgroundColor:\s*Colors\.orange,\s*\),\s*\);',
    r"AppToast.error(context, 'Pilih outlet terlebih dahulu');",
    content
)

content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*const Text\(\s*\'Gerai berhasil ditambahkan\'\),\s*backgroundColor:\s*AppColors\.success,\s*behavior:\s*SnackBarBehavior\.floating,\s*shape:\s*RoundedRectangleBorder\(\s*borderRadius:\s*BorderRadius\.circular\(10\)\),\s*\),\s*\);',
    r"AppToast.success(context, 'Gerai berhasil ditambahkan');",
    content
)

content = re.sub(
    r'ScaffoldMessenger\.of\(ctx\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(e\.toString\(\)\),\s*backgroundColor:\s*AppColors\.danger,\s*behavior:\s*SnackBarBehavior\.floating,\s*shape:\s*RoundedRectangleBorder\(\s*borderRadius:\s*BorderRadius\.circular\(10\)\),\s*\),\s*\);',
    r"AppToast.error(ctx, e.toString());",
    content
)

# Open Shifts Container -> AppCard
content = re.sub(
    r'Container\(\s*margin: const EdgeInsets\.fromLTRB\(16, 0, 16, 12\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(14\),\s*border: Border\.all\(color: const Color\(0xFFFCD34D\)\.withOpacity\(0\.50\)\),\s*boxShadow: \[\s*BoxShadow\(\s*color: Colors\.black\.withOpacity\(0\.05\),\s*blurRadius: 8,\s*offset: const Offset\(0, 2\),\s*\),\s*\],\s*\),\s*child:',
    r'AppCard(\n      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),\n      padding: EdgeInsets.zero,\n      child:',
    content
)

# Metric Card Container -> AppCard
content = re.sub(
    r'Container\(\s*height: 96,\s*padding: const EdgeInsets\.all\(14\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(16\),\s*boxShadow: \[\s*BoxShadow\(\s*color: accent\.withOpacity\(0\.08\),\s*blurRadius: 16,\s*offset: const Offset\(0, 4\),\s*\),\s*\],\s*\),\s*child:',
    r'AppCard(\n      padding: const EdgeInsets.all(14),\n      child: SizedBox(\n        height: 68,\n        child:',
    content
)

# Employee List Container -> AppCard
content = re.sub(
    r'Container\(\s*height: 70,\s*margin: const EdgeInsets\.only\(bottom: 8\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(14\),\s*boxShadow: \[\s*BoxShadow\(\s*color: Colors\.black\.withOpacity\(0\.04\),\s*blurRadius: 8,\s*offset: const Offset\(0, 2\),\s*\),\s*\],\s*\),\s*child: Row\(',
    r'AppCard(\n      margin: const EdgeInsets.only(bottom: 8),\n      padding: EdgeInsets.zero,\n      child: SizedBox(\n        height: 70,\n        child: Row(',
    content
)

# Replace CircularProgressIndicators
content = re.sub(
    r'SizedBox\(\s*height: 100,\s*child: Center\(\s*child: CircularProgressIndicator\(\s*color: AppColors\.primary,\s*strokeWidth: 3,\s*\),\s*\),\s*\)',
    r'_buildDashboardShimmer()',
    content
)

content = re.sub(
    r'const SliverFillRemaining\(\s*hasScrollBody: false,\s*child: Center\(\s*child: Padding\(\s*padding: EdgeInsets\.all\(40\),\s*child: CircularProgressIndicator\(color: AppColors\.primary\),\s*\),\s*\),\s*\)',
    r'SliverFillRemaining(\n                hasScrollBody: false,\n                child: Padding(\n                  padding: const EdgeInsets.all(16),\n                  child: _buildListShimmer(),\n                ),\n              )',
    content
)

content = re.sub(
    r'const Center\(\s*child: CircularProgressIndicator\(\s*color: AppColors\.primary,\s*\),\s*\)',
    r'_buildListShimmer()',
    content
)

content = re.sub(
    r'Center\(\s*child: CircularProgressIndicator\(\s*color: AppColors\.primary,\s*\),\s*\)',
    r'_buildListShimmer()',
    content
)

content = re.sub(
    r'const SizedBox\(\s*width: 16,\s*height: 16,\s*child: CircularProgressIndicator\(\s*strokeWidth: 2,\s*color: Color\(0xFFD97706\),\s*\),\s*\)'
