import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I see the problem - the methods were placed OUTSIDE the _AdminDashboardScreenState class!
# Let's remove them from the end
methods_block = r"""
  Widget _buildListShimmer\(\) \{[\s\S]*?Widget _buildMetricShimmer\(\) \{[\s\S]*?\}\s*\}\s*\}
"""
content = re.sub(methods_block, "", content)

# Remove the unused ones at the end
content = re.sub(r'Widget _buildListShimmer\(\) \{.*?(?=class _SheetField)', '', content, flags=re.DOTALL)
content = re.sub(r'Widget _buildDashboardShimmer\(\) \{.*?(?=class _SheetField)', '', content, flags=re.DOTALL)
content = re.sub(r'Widget _buildMetricShimmer\(\) \{.*?(?=class _SheetField)', '', content, flags=re.DOTALL)

# Re-add exactly before the closing brace of the State class
shimmer_methods = """
  Widget _buildListShimmer() {
    return Column(
      children: List.generate(
        3,
        (index) => AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: ShimmerSkeleton(width: 40, height: 40, borderRadius: 20),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerSkeleton(width: 120, height: 14, borderRadius: 4),
                      SizedBox(height: 8),
                      ShimmerSkeleton(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: ShimmerSkeleton(width: 60, height: 24, borderRadius: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardShimmer() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricShimmer()),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricShimmer()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildMetricShimmer()),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricShimmer()),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricShimmer() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 68,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerSkeleton(width: 32, height: 32, borderRadius: 8),
                ShimmerSkeleton(width: 48, height: 24, borderRadius: 12),
              ],
            ),
            const ShimmerSkeleton(width: 80, height: 12, borderRadius: 4),
          ],
        ),
      ),
    );
  }
"""

end_state_match = re.search(r'}\s*// ─────────────────────────────────────────────────────────────────────────────\s*// Metric Card', content)
if end_state_match:
    content = content[:end_state_match.start()] + shimmer_methods + content[end_state_match.start():]
else:
    content = content.replace("}\n\nclass _MetricCard", shimmer_methods + "}\n\nclass _MetricCard")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
