import 'package:flutter/material.dart';

import 'product_recipes_page.dart';

class RecipesManagementPage extends StatelessWidget {
  const RecipesManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <_RecipeSection>[
      _RecipeSection(
        Icons.menu_book_outlined,
        'PRODUCT RECIPES',
        'Define ingredients and quantities used by products.',
        const ProductRecipesPage(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text(
          'RECIPES MANAGEMENT',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 3
              : constraints.maxWidth >= 650
                  ? 2
                  : 1;
          final width =
              (constraints.maxWidth - (columns - 1) * 16 - 48) / columns;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 8),
              const Icon(
                Icons.menu_book_outlined,
                size: 64,
                color: Color(0xFFC69214),
              ),
              const SizedBox(height: 8),
              const Text(
                'RECIPES',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage product recipes and ingredient usage definitions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final section in sections)
                    SizedBox(
                      width: width,
                      child: _tile(context, section),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, _RecipeSection section) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => section.page),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF171717),
                foregroundColor: Colors.white,
                radius: 26,
                child: Icon(section.icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      section.subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeSection {
  const _RecipeSection(this.icon, this.title, this.subtitle, this.page);

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
}
