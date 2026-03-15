import re

with open('lib/screens/admin/admin_outlets_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix circular progress indicators
content = content.replace("const Center(child: CircularProgressIndicator(color: AppColors.primary))", "_buildOutletShimmer()")

# Fix AppEmptyState not being imported correctly
# Ah wait, the analyzer says "Unused import: '../../widgets/app_empty_state.dart'". Let's see why it's unused.
# Let's verify how the empty state was actually replaced.

content = content.replace(
    """Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada gerai',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )""",
    """AppEmptyState(
                    icon: Icons.store_outlined,
                    heading: 'Belum Ada Gerai',
                    subtext: 'Tambahkan gerai untuk memulai',
                  )"""
)

# And another empty state
content = content.replace(
    """Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.store_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum ada gerai',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )""",
    """AppEmptyState(
                      icon: Icons.store_outlined,
                      heading: 'Belum Ada Gerai',
                      subtext: 'Tambahkan gerai untuk memulai',
                    )"""
)

with open('lib/screens/admin/admin_outlets_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
