import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace snackbars carefully
content = content.replace(
    "ScaffoldMessenger.of(context).showSnackBar(\n          SnackBar(\n            content: Text('Gagal menyimpan: $e'),\n            backgroundColor: AppColors.danger,\n          ),\n        );",
    "AppToast.error(context, 'Gagal menyimpan: $e');"
)

content = content.replace(
    "ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(\n          content: Text('Pilih outlet terlebih dahulu'),\n          backgroundColor: Colors.orange,\n        ),\n      );",
    "AppToast.error(context, 'Pilih outlet terlebih dahulu');"
)

content = content.replace(
    "ScaffoldMessenger.of(context).showSnackBar(\n                                SnackBar(\n                                  content: const Text(\n                                      'Gerai berhasil ditambahkan'),\n                                  backgroundColor: AppColors.success,\n                                  behavior: SnackBarBehavior.floating,\n                                  shape: RoundedRectangleBorder(\n                                      borderRadius:\n                                          BorderRadius.circular(10)),\n                                ),\n                              );",
    "AppToast.success(context, 'Gerai berhasil ditambahkan');"
)

content = content.replace(
    "ScaffoldMessenger.of(ctx).showSnackBar(\n                                SnackBar(\n                                  content: Text(e.toString()),\n                                  backgroundColor: AppColors.danger,\n                                  behavior: SnackBarBehavior.floating,\n                                  shape: RoundedRectangleBorder(\n                                      borderRadius:\n                                          BorderRadius.circular(10)),\n                                ),\n                              );",
    "AppToast.error(ctx, e.toString());"
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
