import 'package:flutter/material.dart';

import '../../../model/category_transaction.dart';
import '../../../ui/device.dart';
import '../../../ui/widgets/native_alert_dialog.dart';

/// Asks how to delete a category: on its own, keeping its transactions
/// (they become uncategorized), or together with all of them.
class ConfirmCategoryDeletionDialog extends StatelessWidget {
  final CategoryTransaction category;

  /// Number of transactions filed under the category (and its subcategories).
  final int transactionCount;

  /// Called with `true` to also delete the transactions.
  final void Function(bool deleteTransactions) onPressed;

  const ConfirmCategoryDeletionDialog({
    required this.category,
    required this.onPressed,
    this.transactionCount = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final noun = category.parent == null ? 'category' : 'subcategory';
    return AdaptiveDialog(
      title: Text('Delete $noun'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Sizes.md,
        children: [
          Text('What should happen to "${category.name}"?'),
          Text(
            transactionCount == 0
                ? 'No transactions are filed under it.'
                : '$transactionCount transaction${transactionCount == 1 ? '' : 's'} '
                      'filed under it can be kept, as uncategorized, or deleted '
                      'with it.',
          ),
          const Text(
            'Recurring transactions and budgets linked to it are always deleted.',
          ),
          const Text('This action cannot be undone.'),
        ],
      ),
      actions: [
        AdaptiveDialogAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        AdaptiveDialogAction(
          child: Text('Delete $noun only'),
          isDestructiveAction: true,
          onPressed: () => onPressed(false),
        ),
        if (transactionCount > 0)
          AdaptiveDialogAction(
            child: const Text('Delete with transactions'),
            isDestructiveAction: true,
            onPressed: () => onPressed(true),
          ),
      ],
    );
  }
}
