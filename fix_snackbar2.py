import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r') as f:
    content = f.read()

# Pattern for ScaffoldMessenger calls
import re

pattern = r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\((?:[^)]|\)[^;])*\)\s*\);'

def repl(match):
    text = match.group(0)
    # Extract the message from Text('...') or Text("...")
    msg_match = re.search(r"Text\(\s*('.*?'|\".*?\")", text)
    if not msg_match:
        return text
    
    msg = msg_match.group(1)
    
    if "AppColors.danger" in text or "Colors.red" in text or "error" in text.lower() or "gagal" in msg.lower():
        return f"AppToast.error(context, {msg});"
    else:
        return f"AppToast.success(context, {msg});"

new_content = re.sub(pattern, repl, content)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w') as f:
    f.write(new_content)
