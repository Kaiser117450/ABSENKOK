import re

with open('lib/screens/admin/admin_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the missing parenthesis in the Employee List Row AppCard
content = content.replace(
"""      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 70,
        child: Row(
        children: [""", 
"""      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 70,
        child: Row(
          children: ["""
)

# And add the closing parenthesis
content = content.replace(
"""            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet Field Helper""",
"""            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet Field Helper"""
)

with open('lib/screens/admin/admin_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
