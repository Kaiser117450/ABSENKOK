import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the circular indicators specifically

# 1. Logs list loading
content = re.sub(
    r'const SliverFillRemaining\(\s*hasScrollBody: false,\s*child: Center\(\s*child: Padding\(\s*padding: EdgeInsets\.all\(40\),\s*child: CircularProgressIndicator\(color: AppColors\.primary\),\s*\),\s*\),\s*\)',
    r'SliverFillRemaining(\n              hasScrollBody: false,\n              child: Padding(\n                padding: const EdgeInsets.all(16),\n                child: _buildListShimmer(),\n              ),\n            )',
    content
)

# Replace remaining direct CircularProgressIndicator within the admin dashboard logs list
content = re.sub(
    r'const SliverFillRemaining\(\s*hasScrollBody: false,\s*child: Center\(\s*child: Padding\(\s*padding: EdgeInsets\.all\(40\),\s*child: CircularProgressIndicator\(color: AppColors\.primary\),\s*\),\s*\),\s*\)',
    r'SliverFillRemaining(\n              hasScrollBody: false,\n              child: Padding(\n                padding: const EdgeInsets.all(16),\n                child: _buildListShimmer(),\n              ),\n            )',
    content
)

# For the metrics grid loading
content = re.sub(
    r'SliverToBoxAdapter\(\s*child: SizedBox\(\s*height: 100,\s*child: Center\(\s*child: CircularProgressIndicator\(\s*color: AppColors\.primary,\s*strokeWidth: 3,\s*\),\s*\),\s*\),\s*\)',
    r'SliverToBoxAdapter(\n            child: Padding(\n              padding: const EdgeInsets.symmetric(horizontal: 16),\n              child: _buildDashboardShimmer(),\n            ),\n          )',
    content
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

