import re

# ==============================================================================
# admin_outlets_screen.dart
# ==============================================================================
with open('lib/screens/admin/admin_outlets_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I notice _buildOutletShimmer is unused. This means I didn't replace the CircularProgressIndicator correctly!
# Wait, looking at the errors:
# error - The method '_buildOutletShimmer' isn't defined for the type '_AdminOutletsScreenState'
# warning - The declaration '_buildOutletShimmer' isn't referenced

# So the definition is outside the class, and the call inside is failing!
# Let's clean it all up.

# 1. Remove all `_buildOutletShimmer` methods completely
content = re.sub(r'Widget _buildOutletShimmer\(\) \{[\s\S]*?\}\s*\}\s*\}\s*\)\s*;\s*\}', '', content)
content = re.sub(r'\s*Widget _buildOutletShimmer\(\) \{[\s\S]*?\}\s*\}\s*\}\s*\)\s*;\s*\}', '', content)

# 2. Inject it safely before `void _showOutletForm`
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

idx = content.find("void _showOutletForm")
if idx != -1:
    content = content[:idx] + shimmer_methods + "\n  " + content[idx:]

# Ensure empty state import
if "AppEmptyState(" in content and "import '../../widgets/app_empty_state.dart';" not in content:
    content = content.replace("import '../../widgets/app_toast.dart';", "import '../../widgets/app_empty_state.dart';\nimport '../../widgets/app_toast.dart';")

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
