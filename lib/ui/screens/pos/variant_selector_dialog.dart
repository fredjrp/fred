// lib/ui/screens/pos/variant_selector_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class VariantSelectorDialog extends StatelessWidget {
  final Product product;
  final void Function(ProductVariant) onSelect;

  const VariantSelectorDialog({
    super.key,
    required this.product,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.read<AuthProvider>().currency;
    final fmt = NumberFormat('#,##0.00');

    return AlertDialog(
      title: Text(product.name),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select variant:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            ...product.variants.map((v) => _VariantTile(
                  variant: v,
                  currency: currency,
                  fmt: fmt,
                  onTap: () {
                    Navigator.pop(context);
                    onSelect(v);
                  },
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _VariantTile extends StatelessWidget {
  final ProductVariant variant;
  final String currency;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _VariantTile({
    required this.variant,
    required this.currency,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = variant.trackStock && variant.stock <= 0;

    return Opacity(
      opacity: isOutOfStock ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isOutOfStock ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(variant.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  if (variant.sku.isNotEmpty)
                    Text('SKU: ${variant.sku}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  '$currency ${fmt.format(variant.price)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.primary),
                ),
                if (variant.trackStock)
                  Text(
                    isOutOfStock ? 'Out of stock' : 'In stock: ${variant.stock.toInt()}',
                    style: TextStyle(
                        fontSize: 11,
                        color: isOutOfStock
                            ? AppColors.danger
                            : variant.isLowStock
                                ? AppColors.warning
                                : AppColors.secondary),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
