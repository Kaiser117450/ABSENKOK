import re

with open('lib/screens/admin/admin_outlets_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

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
    # Let's find exactly the end of the build method for _AdminOutletsScreenState
    # Or just right before _ActionBtn
    idx = content.find("class _ActionBtn extends StatelessWidget {")
    if idx != -1:
        brace_idx = content.rfind("}", 0, idx)
        if brace_idx != -1:
            content = content[:brace_idx] + shimmer_methods + "\n" + content[brace_idx:]

# Empty state
content = content.replace(
    """Center(
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
              )""",
    """AppEmptyState(
                icon: Icons.store_outlined,
                heading: 'Belum Ada Gerai',
                subtext: 'Tambahkan gerai untuk memulai',
              )"""
)

# Containers -> AppCard
content = re.sub(
    r'Container\(\s*margin: const EdgeInsets\.only\(bottom: 12\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(16\),\s*boxShadow: \[\s*BoxShadow\(\s*color: Colors\.black\.withOpacity\([^)]+\),\s*blurRadius: [^,]+,\s*offset: [^\]]+,\s*\),\s*\],\s*\),\s*child:',
    r'AppCard(\n      margin: const EdgeInsets.only(bottom: 12),\n      padding: EdgeInsets.zero,\n      child:',
    content
)

# CircularProgressIndicators
content = content.replace(
    "const Center(child: CircularProgressIndicator())",
    "_buildOutletShimmer()"
)

content = content.replace(
    "const Center(child: CircularProgressIndicator(color: AppColors.primary))",
    "_buildOutletShimmer()"
)

content = content.replace(
    "const Center(\n                            child: CircularProgressIndicator(\n                              color: AppColors.primary,\n                            ),\n                          )",
    "_buildOutletShimmer()"
)

# Snackbars
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?(?:backgroundColor:\s*AppColors\.success[^;]+?|\))\s*\);',
    r"AppToast.success(context, \1);",
    content
)
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?danger[^;]+?\)\s*\);',
    r"AppToast.error(context, \1);",
    content
)
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?Colors\.red[^;]+?\)\s*\);',
    r"AppToast.error(context, \1);",
    content
)
content = re.sub(
    r'ScaffoldMessenger\.of\(ctx\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?danger[^;]+?\)\s*\);',
    r"AppToast.error(ctx, \1);",
    content
)
content = re.sub(
    r'ScaffoldMessenger\.of\(ctx\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?AppColors\.success[^;]+?\)\s*\);',
    r"AppToast.success(ctx, \1);",
    content
)

# Some specific snackbars
content = content.replace(
    """ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gerai berhasil dihapus')),
      );""",
    """AppToast.success(context, 'Gerai berhasil dihapus');"""
)
content = content.replace(
    """ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus gerai: $e'),
            backgroundColor: AppColors.danger,
          ),
        );""",
    """AppToast.error(context, 'Gagal menghapus gerai: $e');"""
)
content = content.replace(
    """ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gerai belum dipilih')),
      );""",
    """AppToast.error(context, 'Gerai belum dipilih');"""
)

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
