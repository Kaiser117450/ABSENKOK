import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure _buildListShimmer is actually defined
if "Widget _buildListShimmer() {" not in content:
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
"""
    # Look for _buildDashboardShimmer to insert next to it
    if "Widget _buildDashboardShimmer() {" in content:
        content = content.replace("Widget _buildDashboardShimmer() {", shimmer_methods + "\n  Widget _buildDashboardShimmer() {")
    else:
        # Otherwise append it to the end of the state class
        content = content.replace("}\n\nclass _MetricCard", shimmer_methods + "}\n\nclass _MetricCard")

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
