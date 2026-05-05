import re

with open('lib/screens/admin/admin_employees_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the regex with unbalanced parenthesis
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?(?:backgroundColor:\s*AppColors\.success[^;]+?|\))\s*\);',
    r"AppToast.success(context, \1);",
    content
)
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?danger[^;]+?\)\s*\);',
    r"AppToast.error(context, \1);",
    content
)
content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?Colors\.red[^;]+?\)\s*\);',
    r"AppToast.error(context, \1);",
    content
)
content = re.sub(
    r'ScaffoldMessenger\.of\(ctx\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\(([^)]+)\)[^;]+?danger[^;]+?\)\s*\);',
    r"AppToast.error(ctx, \1);",
    content
)

# And empty state fixes if not already applied
empty_state = """AppEmptyState(
            icon: Icons.people_outline,
            heading: 'Belum Ada Karyawan',
            subtext: 'Tambahkan karyawan untuk memulai',
          )"""
          
content = re.sub(
    r'Center\(\s*child: Column\(\s*mainAxisAlignment: MainAxisAlignment\.center,\s*children: \[\s*Icon\(\s*Icons\.people_outline,\s*size: 64,\s*color: Colors\.grey\[400\],\s*\),\s*const SizedBox\(height: 16\),\s*Text\(\s*\'Belum ada karyawan\',\s*style: TextStyle\(\s*color: Colors\.grey\[600\],\s*fontSize: 16,\s*\),\s*\),\s*\],\s*\),\s*\)',
    empty_state,
    content
)

with open('lib/screens/admin/admin_employees_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
