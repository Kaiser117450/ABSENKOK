with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

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

  Widget _buildListShimmer() {
    return Column(
      children: List.generate(
        3,
        (index) => AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.zero,
          elevation: 4,
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
}

class _MetricCard"""

# Replace exact string matches
content = content.replace(
    "}\n\nclass _MetricCard", 
    shimmer_methods
)

# Replace circular indicators exactly
content = content.replace(
    "SizedBox(\n                          height: 100,\n                          child: Center(\n                            child: CircularProgressIndicator(\n                              color: AppColors.primary,\n                              strokeWidth: 3,\n                            ),\n                          ),\n                        )",
    "_buildDashboardShimmer()"
)

content = content.replace(
    "const SliverFillRemaining(\n                hasScrollBody: false,\n                child: Center(\n                  child: Padding(\n                    padding: EdgeInsets.all(40),\n                    child: CircularProgressIndicator(color: AppColors.primary),\n                  ),\n                ),\n              )",
    "SliverFillRemaining(\n                hasScrollBody: false,\n                child: Padding(\n                  padding: const EdgeInsets.all(16),\n                  child: _buildListShimmer(),\n                ),\n              )"
)

content = content.replace(
    "const SizedBox(\n                    width: 16,\n                    height: 16,\n                    child: CircularProgressIndicator(\n                      strokeWidth: 2,\n                      color: Color(0xFFD97706),\n                    ),\n                  )",
    "const ShimmerSkeleton(width: 16, height: 16, borderRadius: 8)"
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

