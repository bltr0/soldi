import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/constants.dart';
import '../../model/category_transaction.dart';
import '../../providers/categories_provider.dart';
import '../../providers/transactions_provider.dart';
import '../../ui/device.dart';
import '../../ui/widgets/accent_button.dart';
import '../../ui/widgets/name_hero.dart';
import '../../ui/widgets/segmented_pill.dart';
import 'widgets/category_icon_color_selector.dart';
import 'widgets/confirm_category_deletion_dialog.dart';
import 'widgets/subcategories_list.dart';

class CreateEditCategoryPage extends ConsumerStatefulWidget {
  final bool hideIncome;

  const CreateEditCategoryPage({super.key, this.hideIncome = false});

  @override
  ConsumerState<CreateEditCategoryPage> createState() =>
      _CreateEditCategoryPage();
}

class _CreateEditCategoryPage extends ConsumerState<CreateEditCategoryPage> {
  final TextEditingController nameController = TextEditingController();
  late CategoryTransactionType categoryType;
  String categoryIcon = iconList.keys.first;
  int categoryColor = 0;

  @override
  void initState() {
    super.initState();

    final transactionType = ref.read(selectedTransactionTypeProvider);
    categoryType =
        transactionType.categoryType ?? CategoryTransactionType.expense;

    final selectedCategory = ref.read(selectedCategoryProvider);
    if (selectedCategory != null) {
      nameController.text = selectedCategory.name;
      categoryType = selectedCategory.type;
      categoryIcon = selectedCategory.symbol;
      categoryColor = selectedCategory.color;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (nameController.text.isEmpty) return;
    final notifier = ref.read(categoriesProvider.notifier);
    if (ref.read(selectedCategoryProvider) != null) {
      await notifier.updateCategory(
        name: nameController.text,
        type: categoryType,
        icon: categoryIcon,
        color: categoryColor,
      );
    } else {
      await notifier.addCategory(
        name: nameController.text,
        type: categoryType,
        icon: categoryIcon,
        color: categoryColor,
      );
    }
    // manage_budget_page reads this result: true means a category was saved.
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete(CategoryTransaction category) async {
    final count = await ref
        .read(categoriesProvider.notifier)
        .transactionCount(category);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => ConfirmCategoryDeletionDialog(
        category: category,
        transactionCount: count,
        onPressed: (deleteTransactions) => ref
            .read(categoriesProvider.notifier)
            .removeCategory(category, deleteTransactions: deleteTransactions)
            .whenComplete(() {
              if (context.mounted) {
                Navigator.popUntil(
                  context,
                  ModalRoute.withName('/category-list'),
                );
              }
            }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isNew = selectedCategory == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New category' : 'Edit category'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Sizes.lg,
            Sizes.sm,
            Sizes.lg,
            Sizes.md,
          ),
          child: AccentButton(
            label: isNew ? 'Create category' : 'Save changes',
            icon: isNew ? Icons.add_rounded : Icons.check_rounded,
            onPressed: _save,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Sizes.lg,
          Sizes.lg,
          Sizes.lg,
          Sizes.xl,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          NameHero(
            icon: iconList[categoryIcon],
            color: categoryColorListTheme[categoryColor],
            controller: nameController,
            hint: 'Category name',
          ),
          if (!widget.hideIncome) ...[
            const SizedBox(height: Sizes.lg),
            SegmentedPill<CategoryTransactionType>(
              options: const {
                CategoryTransactionType.expense: 'Expense',
                CategoryTransactionType.income: 'Income',
              },
              selected: categoryType,
              onChanged: (type) => setState(() => categoryType = type),
            ),
          ],
          const SizedBox(height: Sizes.xl),
          CategoryIconColorSelector(
            selectedIcon: categoryIcon,
            selectedColor: categoryColor,
            onIconChanged: (icon) => setState(() => categoryIcon = icon),
            onColorChanged: (color) => setState(() => categoryColor = color),
          ),
          if (!isNew) ...[
            const SizedBox(height: Sizes.xl),
            SubcategoriesList(category: selectedCategory),
            const SizedBox(height: Sizes.xl),
            DeleteAction(
              label: 'Delete category',
              onPressed: () => _delete(selectedCategory),
            ),
          ],
        ],
      ),
    );
  }
}
