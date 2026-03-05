import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure shimmer methods are available
if '_buildListShimmer' not in content:
    content = content.replace(
        "}\n\nclass _MetricCard", 
        """
  Widget _buildListShimmer() {
    return Column(
      children: List.generate(
        3,
        (index) => AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.zero,
          elevation: 4,
          child: const SizedBox(
            height: 70,
            child: Row(
              children: [
                SizedBox(width: 4),
                Padding(
                  padding: EdgeInsets.all(12),
                  child: ShimmerSkeleton(width: 40, height: 40, borderRadius: 20),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerSkeleton(width: 120, height: 14, borderRadius: 4),
                      SizedBox(height: 8),
                      ShimmerSkeleton(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                Padding(
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
      elevation: 4,
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
}

class _MetricCard"""
    )

content = re.sub(
    r'if \(_loading\)[\s\S]*?SliverToBoxAdapter\([\s\S]*?SizedBox\([\s\S]*?height:\s*100,[\s\S]*?Center\([\s\S]*?CircularProgressIndicator[\s\S]*?\)[\s\S]*?\)[\s\S]*?\)[\s\S]*?\)',
    r'if (_loading)\n            SliverToBoxAdapter(\n              child: Padding(\n                padding: const EdgeInsets.symmetric(horizontal: 16),\n                child: _buildDashboardShimmer(),\n              ),\n            )',
    content
)

content = re.sub(
    r'if \(_loading\)[\s\S]*?SliverFillRemaining\([\s\S]*?hasScrollBody:\s*false,[\s\S]*?Center\([\s\S]*?CircularProgressIndicator[\s\S]*?\)[\s\S]*?\)[\s\S]*?\)',
    r'if (_loading)\n            SliverFillRemaining(\n              hasScrollBody: false,\n              child: Padding(\n                padding: const EdgeInsets.all(16),\n                child: _buildListShimmer(),\n              ),\n            )',
    content
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

