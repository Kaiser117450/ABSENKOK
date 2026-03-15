import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

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
      elevation: 4.0,
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

# Let's clean up and make sure we put it exactly inside _AdminDashboardScreenState
# The state class ends at around line 1240 right before _MetricCard

# Find where to put it
content = re.sub(r'Widget _buildListShimmer\(\) \{[\s\S]*?\}\s*\}', '', content)
content = re.sub(r'Widget _buildDashboardShimmer\(\) \{[\s\S]*?Widget _buildMetricShimmer\(\) \{[\s\S]*?\}\s*\}\s*\}', '', content)

content = content.replace("}\n\nclass _MetricCard", shimmer_methods + "}\n\nclass _MetricCard")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

