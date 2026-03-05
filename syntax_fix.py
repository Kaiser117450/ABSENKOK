import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Looks like line 1657 is missing a closing brace or something.
# Wait, where is `Widget _buildListShimmer() {` located right now?
# Based on the snippet, it's at line 1660, which means it got injected into the wrong place again! It got injected right after `Widget build(BuildContext context)` of some class.
