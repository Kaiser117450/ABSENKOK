import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix AppCard usages to remove undefined parameters
# Open shift
content = re.sub(
    r'AppCard\(\s*margin: const EdgeInsets\.fromLTRB\(16, 0, 16, 12\),\s*color: Colors\.white,\s*border: Border\.all\(color: const Color\(0xFFFCD34D\)\.withOpacity\(0\.50\)\),\s*elevation: 4,\s*padding: EdgeInsets\.zero,\s*child:',
    r'AppCard(\n      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),\n      padding: EdgeInsets.zero,\n      child:',
    content
)

content = re.sub(
    r'AppCard\(\s*margin: const EdgeInsets\.fromLTRB\(16, 0, 16, 12\),\s*color: Colors\.white,\s*border: Border\.all\(color: const Color\(0xFFFCD34D\)\.withValues\(alpha: 0\.50\)\),\s*elevation: 4\.0,\s*padding: EdgeInsets\.zero,\s*child:',
    r'AppCard(\n      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),\n      padding: EdgeInsets.zero,\n      child:',
    content
)

# Metric card
content = re.sub(
    r'AppCard\(\s*padding: const EdgeInsets\.all\(14\),\s*elevation: 16\.0,\s*child: SizedBox\(\s*height: 68,',
    r'AppCard(\n      padding: const EdgeInsets.all(14),\n      child: SizedBox(\n        height: 68,',
    content
)

content = re.sub(
    r'AppCard\(\s*padding: const EdgeInsets\.all\(14\),\s*elevation: 16,\s*child: SizedBox\(\s*height: 68,',
    r'AppCard(\n      padding: const EdgeInsets.all(14),\n      child: SizedBox(\n        height: 68,',
    content
)

# Employee List Row
content = re.sub(
    r'AppCard\(\s*margin: const EdgeInsets\.only\(bottom: 8\),\s*padding: EdgeInsets\.zero,\s*elevation: 4\.0,\s*child:',
    r'AppCard(\n      margin: const EdgeInsets.only(bottom: 8),\n      padding: EdgeInsets.zero,\n      child:',
    content
)

content = re.sub(
    r'AppCard\(\s*margin: const EdgeInsets\.only\(bottom: 8\),\s*padding: EdgeInsets\.zero,\s*elevation: 4,\s*child:',
    r'AppCard(\n      margin: const EdgeInsets.only(bottom: 8),\n      padding: EdgeInsets.zero,\n      child:',
    content
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
