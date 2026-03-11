import re

with open('lib/screens/admin/admin_outlets_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Let's cleanly inject `_buildOutletShimmer` right inside `_AdminOutletsScreenState`
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

content = re.sub(r'\s*Widget _buildOutletShimmer\(\) \{[\s\S]*?\}\s*\}\s*\}\s*\)\s*;\s*\}', '', content)

# I will find the first `Widget build` inside `_AdminOutletsScreenState` and put it right before it.
idx = content.find("Widget build(BuildContext context) {")
if idx != -1:
    # also we need to find the `@override` above it to insert properly
    override_idx = content.rfind("@override", 0, idx)
    if override_idx != -1:
        content = content[:override_idx] + shimmer_methods + "\n  " + content[override_idx:]

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

