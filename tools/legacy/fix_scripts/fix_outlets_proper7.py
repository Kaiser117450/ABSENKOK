import re

with open('lib/screens/admin/admin_outlets_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Ah, it's defined inside _MiniStat or _OutletCard? Let's remove it and place it at the end of _AdminOutletsScreenState correctly.
content = re.sub(r'\s*Widget _buildOutletShimmer\(\) \{.*?\n\s*\}\s*\}\s*\}\s*\)\s*;\s*\}', '', content, flags=re.DOTALL)

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

idx = content.find("class _OutletCard")
if idx != -1:
    brace_idx = content.rfind("}", 0, idx)
    if brace_idx != -1:
        content = content[:brace_idx] + shimmer_methods + "\n" + content[brace_idx:]

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
