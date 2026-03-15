import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix AppCard parameters that are throwing errors
content = content.replace("color: Colors.white,\n      border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.50)),\n      elevation: 4,", "color: Colors.white,\n      border: Border.all(color: const Color(0xFFFCD34D).withValues(alpha: 0.50)),\n      elevation: 4.0,")
content = content.replace("elevation: 4,", "elevation: 4.0,")
content = content.replace("elevation: 16,", "elevation: 16.0,")

# Oh wait, AppCard in lib/widgets/app_card.dart has missing parameters!
# Let's fix AppCard first
