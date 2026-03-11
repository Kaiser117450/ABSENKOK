import re

with open('lib/screens/admin/admin_outlets_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the method issue (defined inside another class or outside state)
methods_block = r"""  Widget _buildOutletShimmer\(\) \{[\s\S]*?\}\s*\}\s*\}\s*\}"""

# Remove any existing definition
content = re.sub(methods_block, "", content)
content = re.sub(r'Widget _buildOutletShimmer\(\) \{.*?(?=class _OutletCard)', '', content, flags=re.DOTALL)

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

idx = content.find("class _OutletCard")
if idx != -1:
    brace_idx = content.rfind("}", 0, idx)
    if brace_idx != -1:
        content = content[:brace_idx] + shimmer_methods + content[brace_idx:]

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
