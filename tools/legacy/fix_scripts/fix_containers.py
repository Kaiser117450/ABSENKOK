import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern for inline card Containers
# We're looking for Container( ... decoration: BoxDecoration( ... color: Colors.white ... border ... ) ... )
def replace_container(match):
    full_text = match.group(0)
    
    # Extract padding if it exists
    padding_match = re.search(r'padding:\s*([^,]+),', full_text)
    padding_str = padding_match.group(1) if padding_match else ''
    
    # Extract margin if it exists
    margin_match = re.search(r'margin:\s*([^,]+),', full_text)
    margin_str = margin_match.group(1) if margin_match else ''
    
    # Extract child
    # This is tricky because child can contain nested widgets, so we use string manipulation instead
    return full_text

# Actually, let's just do targeted string replacements to avoid messing up nested widgets
with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

