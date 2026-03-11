import re

with open('lib/screens/admin/admin_outlets_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix unused method _buildOutletShimmer
content = content.replace("const Center(child: CircularProgressIndicator())", "_buildOutletShimmer()")
content = content.replace("const Center(child: CircularProgressIndicator(color: AppColors.primary))", "_buildOutletShimmer()")
content = content.replace("const Center(\n                            child: CircularProgressIndicator(\n                              color: AppColors.primary,\n                            ),\n                          )", "_buildOutletShimmer()")

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

