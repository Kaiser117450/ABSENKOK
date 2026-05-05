import re

# ==============================================================================
# admin_outlets_screen.dart
# ==============================================================================
with open('lib/screens/admin/admin_outlets_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the method issue (defined inside another class or outside state)
methods_block = r"""\s*Widget _buildOutletShimmer\(\) \{[\s\S]*?\}\s*\}\s*\}\s*\)\s*;\s*\}"""
content = re.sub(methods_block, "", content)

# Remove the unused import of AppEmptyState since I see 'AppEmptyState' is now 'Unused import'.
# Did I not replace the empty state? Let's check!
content = content.replace("import '../../widgets/app_empty_state.dart';\n", "")

# Oh, the AppEmptyState issue was because my replacement string didn't match.
empty_state_1 = """Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.store_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada gerai',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )"""

content = content.replace(empty_state_1, """AppEmptyState(
                icon: Icons.store_outlined,
                heading: 'Belum Ada Gerai',
                subtext: 'Tambahkan gerai untuk memulai',
              )""")

# Wait, if it didn't match, let's use regex for empty state
content = re.sub(
    r'Center\(\s*child: Column\(\s*mainAxisAlignment: MainAxisAlignment\.center,\s*children: \[\s*Icon\(\s*Icons\.store_outlined,\s*size: 64,\s*color: Colors\.grey\[400\],\s*\),\s*const SizedBox\(height: 16\),\s*Text\(\s*\'Belum ada gerai\',\s*style: TextStyle\(\s*color: Colors\.grey\[600\],\s*fontSize: 16,\s*\),\s*\),\s*\],\s*\),\s*\)',
    r"AppEmptyState(\n            icon: Icons.store_outlined,\n            heading: 'Belum Ada Gerai',\n            subtext: 'Tambahkan gerai untuk memulai',\n          )",
    content
)

# Bring back AppEmptyState import if needed
if "AppEmptyState(" in content and "import '../../widgets/app_empty_state.dart';" not in content:
    content = content.replace("import '../../widgets/app_toast.dart';", "import '../../widgets/app_empty_state.dart';\nimport '../../widgets/app_toast.dart';")

# Re-inject safely at the end of state class
shimmer_methods = """
  Widget _buildOutletShimmer() {
    return Column(
      children: List.generate(
        3,
        (index) => AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerSkeleton(width: 150, height: 18, borderRadius: 4),
                  ShimmerSkeleton(width: 40, height: 24, borderRadius: 12),
                ],
              ),
              SizedBox(height: 12),
              ShimmerSkeleton(width: double.infinity, height: 14, borderRadius: 4),
              SizedBox(height: 4),
              ShimmerSkeleton(width: 200, height: 14, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
"""

if "_buildOutletShimmer" not in content:
    idx = content.find("class _OutletCard extends StatelessWidget {")
    if idx != -1:
        brace_idx = content.rfind("}", 0, idx)
        if brace_idx != -1:
            content = content[:brace_idx] + shimmer_methods + content[brace_idx:]

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
