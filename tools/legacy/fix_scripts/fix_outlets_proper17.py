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
    idx = content.find("class _OutletSheet extends StatefulWidget {")
    if idx != -1:
        brace_idx = content.rfind("}", 0, idx)
        if brace_idx != -1:
            content = content[:brace_idx] + shimmer_methods + "\n" + content[brace_idx:]

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

