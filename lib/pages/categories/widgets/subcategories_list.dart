import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/constants.dart';
import '../../../model/category_transaction.dart';
import '../../../providers/categories_provider.dart';
import '../../../ui/widgets/picker_sheet.dart';
import '../../../ui/widgets/settings_tiles.dart';

class SubcategoriesList extends ConsumerWidget {
  const SubcategoriesList({super.key, required this.category});

  final CategoryTransaction category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subcategories =
        ref.watch(subcategoriesProvider(category.id!)).value ?? const [];
    return SettingsGroup(
      title: 'Subcategories',
      children: [
        for (final subcategory in subcategories)
          SettingsTile(
            title: subcategory.name,
            onTap: () {
              ref
                  .read(selectedSubcategoryProvider.notifier)
                  .setCategory(subcategory);
              Navigator.of(context).pushNamed(
                '/add-subcategory',
                arguments: {'category': subcategory},
              );
            },
            trailing: PickerIcon(
              icon: iconList[subcategory.symbol],
              color: categoryColorListTheme[subcategory.color],
            ),
          ),
        SettingsTile(
          icon: Icons.add_rounded,
          title: 'Add subcategory',
          onTap: () {
            ref.invalidate(selectedSubcategoryProvider);
            Navigator.of(
              context,
            ).pushNamed('/add-subcategory', arguments: {'category': category});
          },
        ),
      ],
    );
  }
}
