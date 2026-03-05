import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the missing parenthesis from the Employee list row card replacement
content = re.sub(
    r'AppCard\(\s*margin: const EdgeInsets\.only\(bottom: 8\),\s*padding: EdgeInsets\.zero,\s*child: SizedBox\(\s*height: 70,\s*child: Row\(([\s\S]*?)(\s*)\)(;|,)?(\s*)\]',
    r'AppCard(\n      margin: const EdgeInsets.only(bottom: 8),\n      padding: EdgeInsets.zero,\n      child: SizedBox(\n        height: 70,\n        child: Row(\1\2)\3\4]',
    content
)

# Insert shimmer methods
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

if "_buildListShimmer" not in content:
    idx = content.find("class _SheetField extends StatelessWidget {")
    if idx != -1:
        # Find the previous closing brace `}` 
        prev_brace = content.rfind("}", 0, idx)
        if prev_brace != -1:
            content = content[:prev_brace] + shimmer_methods + content[prev_brace:]

# Replace CircularProgressIndicators
content = content.replace(
    """SizedBox(
                          height: 100,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 3,
                            ),
                          ),
                        )""",
    """_buildDashboardShimmer()"""
)

content = content.replace(
    """const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              )""",
    """SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildListShimmer(),
                ),
              )"""
)

content = content.replace(
    """Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )""",
    """_buildListShimmer()"""
)

content = content.replace(
    """const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )""",
    """_buildListShimmer()"""
)

content = content.replace(
    """const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFD97706),
                    ),
                  )""",
    """const ShimmerSkeleton(width: 16, height: 16, borderRadius: 8)"""
)

content = content.replace(
    """const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Color(0xFF1A0A00), strokeWidth: 2.5),
                        )""",
    """const SizedBox(
                          width: 20,
                          height: 20,
                          child: ShimmerSkeleton(width: 20, height: 20, borderRadius: 10),
                        )"""
)

# Write back
with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

