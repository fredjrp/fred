// lib/ui/screens/pos/pos_screen.dart
// Core POS: product grid on left, cart + checkout on right.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import 'checkout_dialog.dart';
import 'customer_selector.dart';
import 'variant_selector_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl = TextEditingController();
  bool _cartExpanded = false; // for mobile: toggle cart panel

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadFromLocal();
      context.read<CustomerProvider>().loadFromLocal();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _addProduct(Product product) {
    final inventory = context.read<InventoryProvider>();
    final cart = context.read<CartProvider>();

    if (product.hasMultipleVariants) {
      showDialog(
        context: context,
        builder: (_) => VariantSelectorDialog(
          product: product,
          onSelect: (variant) {
            final taxRate = variant.taxRateId.isNotEmpty
                ? inventory.getTaxRateById(product.taxRateId)
                : (product.taxRateId.isNotEmpty
                    ? inventory.getTaxRateById(product.taxRateId)
                    : null);
            cart.addItem(product, variant, taxRate);
          },
        ),
      );
    } else {
      final variant = product.defaultVariant;
      if (variant == null) return;
      final taxRate = product.taxRateId.isNotEmpty
          ? inventory.getTaxRateById(product.taxRateId)
          : null;
      cart.addItem(product, variant, taxRate);
    }
  }

  void _handleBarcodeSearch(String value) {
    if (value.isEmpty) return;
    final inventory = context.read<InventoryProvider>();
    final product = inventory.findByBarcode(value);
    if (product != null) {
      _addProduct(product);
      _searchCtrl.clear();
      inventory.setSearch('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isDesktop
          ? Row(children: [
              Expanded(flex: 3, child: _ProductPanel(
                searchCtrl: _searchCtrl,
                onProductTap: _addProduct,
                onBarcodeSearch: _handleBarcodeSearch,
              )),
              Container(width: 1, color: AppColors.divider),
              SizedBox(width: 360, child: _CartPanel()),
            ])
          : Stack(children: [
              _ProductPanel(
                searchCtrl: _searchCtrl,
                onProductTap: _addProduct,
                onBarcodeSearch: _handleBarcodeSearch,
              ),
              // Mobile floating cart button
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _MobileCartButton(
                  itemCount: cart.itemCount,
                  total: cart.total,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.75,
                        minChildSize: 0.4,
                        maxChildSize: 0.95,
                        builder: (_, scrollCtrl) => Container(
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: _CartPanel(scrollController: scrollCtrl),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}

// ─── PRODUCT PANEL ───────────────────────────
class _ProductPanel extends StatelessWidget {
  final TextEditingController searchCtrl;
  final void Function(Product) onProductTap;
  final void Function(String) onBarcodeSearch;

  const _ProductPanel({
    required this.searchCtrl,
    required this.onProductTap,
    required this.onBarcodeSearch,
  });

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final auth = context.watch<AuthProvider>();
    final currency = auth.currency;
    final fmt = NumberFormat('#,##0.00');

    return Column(children: [
      // Top bar
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            Row(children: [
              Expanded(
                child: AppSearchBar(
                  hint: 'Search products or scan barcode...',
                  controller: searchCtrl,
                  onChanged: (v) {
                    inventory.setSearch(v);
                    // If looks like barcode (all digits, length >= 8)
                    if (v.length >= 8 && RegExp(r'^\d+$').hasMatch(v)) {
                      onBarcodeSearch(v);
                    }
                  },
                  onClear: () {
                    searchCtrl.clear();
                    inventory.setSearch('');
                  },
                ),
              ),
              const SizedBox(width: 8),
              _SyncButton(),
            ]),
            const SizedBox(height: 8),
            // Category filter chips
            if (inventory.categories.isNotEmpty)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: inventory.categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    if (i == 0) {
                      return FilterChip(
                        label: const Text('All'),
                        selected: inventory.selectedCategoryId.isEmpty,
                        onSelected: (_) => inventory.setCategory(''),
                      );
                    }
                    final cat = inventory.categories[i - 1];
                    return FilterChip(
                      label: Text(cat.name),
                      selected: inventory.selectedCategoryId == cat.id,
                      onSelected: (_) => inventory.setCategory(cat.id),
                    );
                  },
                ),
              ),
          ]),
        ),
      ),
      const Divider(height: 1),
      // Product grid
      Expanded(
        child: inventory.isLoading
            ? const Center(child: CircularProgressIndicator())
            : inventory.products.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No Products',
                    subtitle: 'Add products in the Inventory tab.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: Responsive.productGridColumns(context),
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: inventory.products.length,
                    itemBuilder: (ctx, i) {
                      final p = inventory.products[i];
                      final catColor = inventory.getCategoryById(p.categoryId)?.color;
                      return ProductCard(
                        name: p.name,
                        price: '$currency ${fmt.format(p.defaultPrice)}',
                        imageUrl: p.imageUrl.isNotEmpty ? p.imageUrl : null,
                        categoryColor: catColor,
                        isLowStock: p.isLowStock,
                        onTap: () => onProductTap(p),
                      );
                    },
                  ),
      ),
    ]);
  }
}

// ─── CART PANEL ──────────────────────────────
class _CartPanel extends StatelessWidget {
  final ScrollController? scrollController;
  const _CartPanel({this.scrollController});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();
    final currency = auth.currency;
    final fmt = NumberFormat('#,##0.00');

    return Container(
      color: AppColors.surface,
      child: Column(children: [
        // Cart header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(children: [
            Text('Order', style: Theme.of(context).textTheme.titleLarge),
            if (cart.itemCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${cart.itemCount}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            const Spacer(),
            // Customer button
            _CustomerButton(),
            if (cart.items.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.danger, size: 20),
                onPressed: () => _confirmClear(context, cart),
                tooltip: 'Clear Cart',
              ),
          ]),
        ),
        // Customer badge
        if (cart.customer != null) _CustomerBadge(customer: cart.customer!),
        const Divider(height: 1),

        // Cart items
        Expanded(
          child: cart.items.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 48, color: AppColors.textTertiary),
                    SizedBox(height: 8),
                    Text('Cart is empty',
                        style: TextStyle(color: AppColors.textSecondary)),
                    Text('Tap a product to add it',
                        style:
                            TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  ]),
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (ctx, i) => _CartItemRow(
                    item: cart.items[i],
                    index: i,
                    currency: currency,
                    fmt: fmt,
                    onQtyChanged: (qty) => cart.updateQuantity(i, qty),
                    onRemove: () => cart.removeItem(i),
                    onDiscount: () => _showItemDiscountSheet(ctx, i, cart),
                  ),
                ),
        ),

        // Totals & Checkout
        if (cart.items.isNotEmpty) ...[
          const Divider(height: 1),
          _CartTotals(cart: cart, currency: currency, fmt: fmt),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _openCheckout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Charge $currency ${fmt.format(cart.total)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  void _confirmClear(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from the cart?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); cart.clear(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showItemDiscountSheet(BuildContext context, int index, CartProvider cart) {
    final inventory = context.read<InventoryProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _ItemDiscountSheet(
        discounts: inventory.discounts,
        onApply: (d) {
          cart.applyItemDiscount(index, d);
          Navigator.pop(ctx);
        },
        onRemove: () {
          cart.removeItemDiscount(index);
          Navigator.pop(ctx);
        },
        hasDiscount: cart.items[index].discountAmount > 0,
      ),
    );
  }

  void _openCheckout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CheckoutDialog(),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final int index;
  final String currency;
  final NumberFormat fmt;
  final ValueChanged<double> onQtyChanged;
  final VoidCallback onRemove;
  final VoidCallback onDiscount;

  const _CartItemRow({
    required this.item,
    required this.index,
    required this.currency,
    required this.fmt,
    required this.onQtyChanged,
    required this.onRemove,
    required this.onDiscount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Info
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.productName,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            if (item.variantName.isNotEmpty && item.variantName != 'Default')
              Text(item.variantName,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(children: [
              Text('$currency ${fmt.format(item.price)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              if (item.discountAmount > 0) ...[
                const SizedBox(width: 4),
                Text('-$currency ${fmt.format(item.discountAmount)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.danger)),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        // Controls
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '$currency ${fmt.format(item.total)}',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Row(children: [
            InkWell(
              onTap: onDiscount,
              child: const Icon(Icons.local_offer_outlined,
                  size: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            QuantityStepper(value: item.quantity, onChanged: onQtyChanged, min: 0),
          ]),
        ]),
      ]),
    );
  }
}

class _CartTotals extends StatelessWidget {
  final CartProvider cart;
  final String currency;
  final NumberFormat fmt;
  const _CartTotals({required this.cart, required this.currency, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(children: [
        _row('Subtotal', '$currency ${fmt.format(cart.subtotal)}'),
        if (cart.totalDiscount > 0)
          _row('Discount', '-$currency ${fmt.format(cart.totalDiscount)}', isRed: true),
        if (cart.totalTax > 0)
          _row('Tax', '$currency ${fmt.format(cart.totalTax)}'),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text('$currency ${fmt.format(cart.total)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
        // Order discount button
        const SizedBox(height: 6),
        _OrderDiscountButton(cart: cart),
      ]),
    );
  }

  Widget _row(String label, String value, {bool isRed = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      Text(value, style: TextStyle(fontSize: 13, color: isRed ? AppColors.danger : AppColors.textPrimary, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _OrderDiscountButton extends StatelessWidget {
  final CartProvider cart;
  const _OrderDiscountButton({required this.cart});

  @override
  Widget build(BuildContext context) {
    final discounts = context.read<InventoryProvider>().discounts;
    if (discounts.isEmpty) return const SizedBox.shrink();

    if (cart.orderDiscount != null) {
      return TextButton.icon(
        onPressed: () => cart.setOrderDiscount(null),
        icon: const Icon(Icons.close, size: 14, color: AppColors.danger),
        label: Text('Remove Discount (${cart.orderDiscount!.name})',
            style: const TextStyle(color: AppColors.danger, fontSize: 12)),
      );
    }

    return TextButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => _DiscountPickerSheet(
            discounts: discounts,
            onPick: (d) { cart.setOrderDiscount(d); Navigator.pop(ctx); },
          ),
        );
      },
      icon: const Icon(Icons.local_offer_outlined, size: 14),
      label: const Text('Add Order Discount', style: TextStyle(fontSize: 12)),
    );
  }
}

class _DiscountPickerSheet extends StatelessWidget {
  final List<Discount> discounts;
  final void Function(Discount) onPick;
  const _DiscountPickerSheet({required this.discounts, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Select Discount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      const Divider(height: 1),
      ...discounts.map((d) => ListTile(
        leading: const Icon(Icons.local_offer_outlined, color: AppColors.primary),
        title: Text(d.name),
        subtitle: Text(d.type == 'percentage' ? '${d.value}%' : 'Fixed ${d.value}'),
        onTap: () => onPick(d),
      )),
      const SizedBox(height: 16),
    ]);
  }
}

class _ItemDiscountSheet extends StatelessWidget {
  final List<Discount> discounts;
  final void Function(Discount) onApply;
  final VoidCallback onRemove;
  final bool hasDiscount;
  const _ItemDiscountSheet({required this.discounts, required this.onApply, required this.onRemove, required this.hasDiscount});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Item Discount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      const Divider(height: 1),
      if (hasDiscount)
        ListTile(
          leading: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
          title: const Text('Remove Discount', style: TextStyle(color: AppColors.danger)),
          onTap: onRemove,
        ),
      ...discounts.map((d) => ListTile(
        leading: const Icon(Icons.local_offer_outlined, color: AppColors.primary),
        title: Text(d.name),
        subtitle: Text(d.type == 'percentage' ? '${d.value}% off' : 'Fixed -${d.value}'),
        onTap: () => onApply(d),
      )),
      const SizedBox(height: 16),
    ]);
  }
}

class _CustomerButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    if (cart.customer != null) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => CustomerSelectorSheet(
            onSelect: (c) => context.read<CartProvider>().setCustomer(c),
          ),
        );
      },
      icon: const Icon(Icons.person_add_outlined, size: 16),
      label: const Text('Customer', style: TextStyle(fontSize: 12)),
    );
  }
}

class _CustomerBadge extends StatelessWidget {
  final Customer customer;
  const _CustomerBadge({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        const Icon(Icons.person, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary)),
            Text('${customer.loyaltyPoints.toInt()} pts', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 14, color: AppColors.primary),
          onPressed: () => context.read<CartProvider>().setCustomer(null),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }
}

class _SyncButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();
    return IconButton(
      icon: Icon(
        connectivity.isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
        color: connectivity.isOnline ? AppColors.secondary : AppColors.warning,
        size: 20,
      ),
      tooltip: connectivity.isOnline ? 'Online' : 'Offline',
      onPressed: connectivity.isOnline
          ? () async {
              final storeId = context.read<AuthProvider>().storeId;
              final pushed = await context.read<TransactionProvider>().syncPending(storeId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(pushed > 0 ? 'Synced $pushed transactions' : 'All synced'),
                  backgroundColor: AppColors.secondary,
                ));
              }
            }
          : null,
    );
  }
}

class _MobileCartButton extends StatelessWidget {
  final int itemCount;
  final double total;
  final VoidCallback onTap;
  const _MobileCartButton({required this.itemCount, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    final currency = context.read<AuthProvider>().currency;
    final fmt = NumberFormat('#,##0.00');

    return SafeArea(
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.primary,
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Text('$itemCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('View Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))),
              Text('$currency ${fmt.format(total)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
        ),
      ),
    );
  }
}
