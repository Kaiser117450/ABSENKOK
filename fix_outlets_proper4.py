import re

# ==============================================================================
# admin_outlets_screen.dart
# ==============================================================================
with open('lib/screens/admin/admin_outlets_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the unused elements and errors
content = content.replace("import 'dart:math';\n", "")

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

# Let's remove the badly placed _buildOutletShimmer completely
content = re.sub(r'\s*Widget _buildOutletShimmer\(\) \{.*?\n\s*\}\s*\}\s*\}\s*\)\s*;\s*\}', '', content, flags=re.DOTALL)

# And put it where it actually belongs: right before `void _showOutletForm`
idx = content.find("void _showOutletForm")
if idx != -1:
    content = content[:idx] + shimmer_methods + "\n  " + content[idx:]

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
