import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/category_icons.dart';
import '../../../core/icons.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/theme.dart';
import '../../shared/app_dialogs.dart';
import '../../shared/empty_state.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  Future<void> _addCategory() async {
    final name = await promptForText(context,
        title: 'New category', hint: 'e.g. Food, Transport', confirmLabel: 'Add');
    if (name == null || !mounted) return;
    await ref.read(databaseProvider).addCategory(name);
  }

  Future<void> _renameCategory(CategoryRow cat) async {
    final name = await promptForText(context,
        title: 'Rename category', initial: cat.name);
    if (name == null || !mounted) return;
    await ref.read(databaseProvider).renameCategory(cat.id, name);
  }

  Future<void> _deleteCategory(CategoryRow cat) async {
    final ok = await confirmDestructive(context,
        title: 'Delete "${cat.name}"?',
        message: 'Records keep their history but lose this category.');
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteCategory(cat.id);
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _addCategory,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: XSwitcher(
          child: cats.isEmpty
              ? EmptyState(
                  key: const ValueKey('cats-empty'),
                  icon: AppIcons.category,
                  title: 'No categories yet',
                  message: 'Group your spending to see where it goes.',
                  actionLabel: 'Add category',
                  onAction: _addCategory,
                )
              : ListView.separated(
                  key: const ValueKey('cats-list'),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  itemCount: cats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 1),
                  itemBuilder: (_, i) {
                    final cat = cats[i];
                    return FadeIn(
                      key: ValueKey(cat.id),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: context.hairline),
                          borderRadius: BorderRadius.circular(14),
                          color: context.cardSurface,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: IconBadge(iconForCategory(cat.name),
                              size: 40, tinted: true),
                          title: Text(cat.name,
                              style:
                                  AppTextStyles.body.copyWith(color: context.ink,
                                  fontWeight: FontWeight.w600)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_rounded,
                                    size: 20, color: context.inkMuted),
                                onPressed: () => _renameCategory(cat),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 20, color: context.palette.dangerContent),
                                onPressed: () => _deleteCategory(cat),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
