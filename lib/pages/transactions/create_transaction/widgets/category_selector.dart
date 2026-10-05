import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../constants/constants.dart';
import '../../../../model/category_transaction.dart';
import '../../../../providers/categories_provider.dart';
import '../../../../providers/transactions_provider.dart';
import '../../../../ui/device.dart';
import '../../../../ui/widgets/picker_sheet.dart';

class CategorySelector extends ConsumerStatefulWidget {
  const CategorySelector({required this.scrollController, super.key});

  final ScrollController? scrollController;

  @override
  ConsumerState<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends ConsumerState<CategorySelector> {
  void _commit(CategoryTransaction? category) {
    ref.read(selectedCategoryProvider.notifier).setCategory(category);
    Navigator.of(context).pop();
  }

  Future<void> _selectParentOrCommit(CategoryTransaction category) async {
    final subcategories = await ref.read(
      subcategoriesProvider(category.id!).future,
    );
    if (!mounted) return;
    final alreadySelected =
        ref.read(selectedCategoryProvider)?.id == category.id;
    if (subcategories.isNotEmpty && !alreadySelected) {
      ref.read(selectedCategoryProvider.notifier).setCategory(category);
      return;
    }
    _commit(category);
  }

  @override
  Widget build(BuildContext context) {
    final transactionType = ref.watch(selectedTransactionTypeProvider);
    final categoriesList = ref.watch(
      categoriesByTypeProvider(transactionType.categoryType),
    );
    final frequentCategories = ref.watch(
      frequentCategoriesProvider(transactionType.categoryType),
    );
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: Sizes.xl),
      children: [
        PickerSheetHeader(
          title: 'Category',
          subtitle: 'Tap a category twice to skip its subcategories',
          onAdd: () => Navigator.of(context).pushNamed('/add-category'),
        ),
        ...frequentCategories.maybeWhen(
          data: (categories) => categories.isEmpty
              ? const <Widget>[]
              : [
                  const PickerSectionLabel('Frequent'),
                  SizedBox(
                    height: 76,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sizes.sm,
                      ),
                      children: [
                        for (final category in categories)
                          PickerChip(
                            label: category.name,
                            icon: iconList[category.symbol],
                            color: categoryColorListTheme[category.color],
                            onTap: () => _selectParentOrCommit(category),
                          ),
                      ],
                    ),
                  ),
                ],
          orElse: () => const <Widget>[],
        ),
        const PickerSectionLabel('All categories'),
        PickerRow(
          leading: const PickerIcon(icon: Icons.label_off_rounded, color: null),
          title: 'Uncategorized',
          selected: selectedCategory == null,
          onTap: () => _commit(null),
        ),
        ...categoriesList.when(
          data: (categories) => [
            for (final category in categories) ...[
              PickerRow(
                leading: PickerIcon(
                  icon: iconList[category.symbol],
                  color: categoryColorListTheme[category.color],
                ),
                title: category.name,
                selected: selectedCategory?.id == category.id,
                onTap: () => _selectParentOrCommit(category),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child:
                    selectedCategory?.id == category.id ||
                        selectedCategory?.parent == category.id
                    ? ref
                          .watch(subcategoriesProvider(category.id!))
                          .maybeWhen(
                            data: (subcategories) => Column(
                              children: [
                                for (final subcategory in subcategories)
                                  PickerRow(
                                    indent: Sizes.xl,
                                    leading: PickerIcon(
                                      icon: iconList[subcategory.symbol],
                                      color: categoryColorListTheme[subcategory
                                          .color],
                                    ),
                                    title: subcategory.name,
                                    selected:
                                        selectedCategory?.id == subcategory.id,
                                    onTap: () => _commit(subcategory),
                                  ),
                              ],
                            ),
                            orElse: () => const SizedBox(
                              width: double.infinity,
                            ),
                          )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ],
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(Sizes.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (err, _) => [Center(child: Text('Error: $err'))],
        ),
      ],
    );
  }
}

Future<void> showCategorySelector(BuildContext context) => showPickerSheet<void>(
  context,
  builder: (_, controller) => CategorySelector(scrollController: controller),
);
