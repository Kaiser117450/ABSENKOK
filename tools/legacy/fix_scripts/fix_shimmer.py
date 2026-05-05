import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern for CircularProgressIndicator 1 (Open shifts list)
content = re.sub(
    r'Center\(child: CircularProgressIndicator\(color: AppColors\.primary\)\)',
    r'_buildListShimmer()',
    content
)

# Pattern for CircularProgressIndicator 2 (Metrics Grid)
content = re.sub(
    r'SizedBox\(\s*height: 100,\s*child: Center\(\s*child: CircularProgressIndicator\(\s*color: AppColors\.primary,\s*strokeWidth: 3,\s*\),\s*\),\s*\)',
    r'_buildDashboardShimmer()',
    content
)

# Pattern for CircularProgressIndicator 3 (Logs List)
content = re.sub(
    r'Center\(\s*child: CircularProgressIndicator\(\s*color: AppColors\.primary,\s*\),\s*\)',
    r'_buildListShimmer()',
    content
)

# Add shimmer methods to _AdminDashboardScreenState
if '_buildDashboardShimmer' not in content:
    shimmer_methods = """
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
              children: [
                const ShimmerSkeleton(width: 32, height: 32, borderRadius: 8),
                const ShimmerSkeleton(width: 48, height: 24, borderRadius: 12),
              ],
            ),
            const ShimmerSkeleton(width: 80, height: 12, borderRadius: 4),
          ],
        ),
      ),
    );
  }

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
"""
    # Insert before the last closing brace
    content = content.replace("}\n\nclass _MetricCard extends StatelessWidget {", shimmer_methods + "}\n\nclass _MetricCard extends StatelessWidget {")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

