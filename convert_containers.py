import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace Open Shift Container
content = re.sub(
    r'Container\(\s*margin: const EdgeInsets\.fromLTRB\(16, 0, 16, 12\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(14\),\s*border: Border\.all\(color: const Color\(0xFFFCD34D\)\.withOpacity\(0\.50\)\),\s*boxShadow: \[\s*BoxShadow\(\s*color: Colors\.black\.withOpacity\(0\.05\),\s*blurRadius: 10,\s*offset: const Offset\(0, 4\),\s*\),\s*\],\s*\),\s*child:',
    r'AppCard(\n      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),\n      color: Colors.white,\n      border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.50)),\n      elevation: 4,\n      padding: EdgeInsets.zero,\n      child:',
    content
)

# Replace Dashboard Metric Card Container
content = re.sub(
    r'Container\(\s*height: 96,\s*padding: const EdgeInsets\.all\(14\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(16\),\s*boxShadow: \[\s*BoxShadow\(\s*color: accent\.withOpacity\(0\.08\),\s*blurRadius: 16,\s*offset: const Offset\(0, 6\),\s*\),\s*\],\s*\),\s*child:',
    r'AppCard(\n      padding: const EdgeInsets.all(14),\n      elevation: 16,\n      child: SizedBox(\n        height: 68,\n        child:',
    content
)

# Replace Employee List Row Container
content = re.sub(
    r'Container\(\s*height: 70,\s*margin: const EdgeInsets\.only\(bottom: 8\),\s*decoration: BoxDecoration\(\s*color: Colors\.white,\s*borderRadius: BorderRadius\.circular\(14\),\s*boxShadow: \[\s*BoxShadow\(\s*color: Colors\.black\.withOpacity\(0\.04\),\s*blurRadius: 8,\s*offset: const Offset\(0, 4\),\s*\),\s*\],\s*\),\s*child:',
    r'AppCard(\n      margin: const EdgeInsets.only(bottom: 8),\n      padding: EdgeInsets.zero,\n      elevation: 4,\n      child: SizedBox(\n        height: 70,\n        child:',
    content
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

