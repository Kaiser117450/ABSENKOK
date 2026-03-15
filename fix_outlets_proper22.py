import re

with open('lib/screens/admin/admin_outlets_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Let's fix the missing method _buildOutletShimmer for real.
# The error says `The method '_buildOutletShimmer' isn't defined for the type '_AdminOutletsScreenState'` but also says `The declaration '_buildOutletShimmer' isn't referenced` at line 554. This means I put it OUTSIDE the _AdminOutletsScreenState class!

# Let's completely remove it.
content = re.sub(r'\s*Widget _buildOutletShimmer\(\) \{[\s\S]*?\}\s*\}\s*\}\s*\)\s*;\s*\}', '', content)
content = re.sub(r'Widget _buildOutletShimmer\(\) \{[\s\S]*?\}\s*\}\s*\}\s*\)\s*;\s*\}', '', content)

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

# Let's inject it precisely inside the _AdminOutletsScreenState class by finding `void _showOutletForm`
idx = content.find("void _showOutletForm")
if idx != -1:
    content = content[:idx] + shimmer_methods + "\n  " + content[idx:]

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

