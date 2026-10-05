import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/constants.dart';
import '../../model/category_transaction.dart';
import '../../providers/categories_provider.dart';
import '../../ui/device.dart';
import '../../ui/widgets/accent_button.dart';
import '../../ui/widgets/name_hero.dart';
import 'widgets/category_icon_color_selector.dart';
import 'widgets/confirm_category_deletion_dialog.dart';

class CreateEditSubcategoryPage extends ConsumerStatefulWidget {
  final CategoryTransaction category;

  const CreateEditSubcategoryPage({super.key, required this.category});

  @override
  ConsumerState<CreateEditSubcategoryPage> createState() =>
      _CreateEditSubcategoryPage();
}

class _CreateEditSubcategoryPage
    extends ConsumerState<CreateEditSubcategoryPage> {
  final TextEditingController nameController = TextEditingController();
  late CategoryTransactionType categoryType;
  String categoryIcon = iconList.keys.first;
  int categoryColor = 0;

  @override
  void initState() {
    super.initState();

    categoryType = widget.category.type;
    categoryColor = widget.category.color;

    final selectedSubcategory = ref.read(selectedSubcategoryProvider);
    if (selectedSubcategory != null) {
      nameController.text = selectedSubcategory.name;
      categoryType = selectedSubcategory.type;
      categoryIcon = selectedSubcategory.symbol;
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
    if (ref.read(selectedSubcategoryProvider) != null) {
      await notifier.updateSubcategory(
        name: nameController.text,
        icon: categoryIcon,
      );
    } else {
      await notifier.addSubcategory(name: nameController.text, icon: categoryIcon);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete(CategoryTransaction subcategory) async {
    final count = await ref
        .read(categoriesProvider.notifier)
        .transactionCount(subcategory);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => ConfirmCategoryDeletionDialog(
        category: subcategory,
        transactionCount: count,
        onPressed: (deleteTransactions) => ref
            .read(categoriesProvider.notifier)
            .removeCategory(subcategory, deleteTransactions: deleteTransactions)
            .whenComplete(() {
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) Navigator.of(context).pop();
            }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedSubcategory = ref.watch(selectedSubcategoryProvider);
    final isNew = selectedSubcategory == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New subcategory' : 'Edit subcategory'),
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
            label: isNew ? 'Create subcategory' : 'Save changes',
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
            hint: 'Subcategory name',
          ),
          const SizedBox(height: Sizes.xl),
          CategoryIconColorSelector(
            selectedIcon: categoryIcon,
            selectedColor: categoryColor,
            onIconChanged: (icon) => setState(() => categoryIcon = icon),
          ),
          if (!isNew) ...[
            const SizedBox(height: Sizes.xl),
            DeleteAction(
              label: 'Delete subcategory',
              onPressed: () => _delete(selectedSubcategory),
            ),
          ],
        ],
      ),
    );
  }
}
