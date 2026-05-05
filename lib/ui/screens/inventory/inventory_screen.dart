// lib/ui/screens/inventory/inventory_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../services/firebase_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeId = context.read<AuthProvider>().storeId;
      context.read<InventoryProvider>().syncFromFirebase(storeId);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: 'Products (${inventory.allProducts.length})'),
            Tab(text: 'Categories (${inventory.categories.length})'),
            const Tab(text: 'Settings'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              final storeId = context.read<AuthProvider>().storeId;
              inventory.syncFromFirebase(storeId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              switch (_tabCtrl.index) {
                case 0: _openProductForm(context, null); break;
                case 1: _openCategoryForm(context, null); break;
                case 2: break;
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ProductsTab(onEdit: (p) => _openProductForm(context, p)),
          _CategoriesTab(onEdit: (c) => _openCategoryForm(context, c)),
          const _SettingsTab(),
        ],
      ),
    );
  }

  void _openProductForm(BuildContext context, Product? product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
  }

  void _openCategoryForm(BuildContext context, Category? category) {
    showDialog(
      context: context,
      builder: (_) => CategoryFormDialog(category: category),
    );
  }
}

// ─── PRODUCTS TAB ────────────────────────────
class _ProductsTab extends StatelessWidget {
  final void Function(Product) onEdit;
  const _ProductsTab({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final currency = context.watch<AuthProvider>().currency;
    final fmt = NumberFormat('#,##0.00');

    final products = inventory.allProducts.where((p) {
      final q = inventory.searchQuery.toLowerCase();
      return q.isEmpty || p.name.toLowerCase().contains(q);
    }).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: AppSearchBar(
          hint: 'Search products...',
          onChanged: inventory.setSearch,
        ),
      ),
      if (inventory.lowStockProducts.isNotEmpty)
        _LowStockBanner(count: inventory.lowStockProducts.length),
      Expanded(
        child: inventory.isLoading
            ? const Center(child: CircularProgressIndicator())
            : products.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No Products',
                    subtitle: 'Add your first product.',
                    actionLabel: 'Add Product',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProductFormScreen(product: null)),
                    ),
                  )
                : ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                    itemBuilder: (ctx, i) {
                      final p = products[i];
                      final cat = inventory.getCategoryById(p.categoryId);
                      return _ProductListTile(
                        product: p,
                        category: cat,
                        currency: currency,
                        fmt: fmt,
                        onTap: () => onEdit(p),
                        onDelete: () => _deleteProduct(ctx, p),
                      );
                    },
                  ),
      ),
    ]);
  }

  void _deleteProduct(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final storeId = context.read<AuthProvider>().storeId;
      await context.read<InventoryProvider>().deleteProduct(storeId, product.id);
    }
  }
}

class _ProductListTile extends StatelessWidget {
  final Product product;
  final Category? category;
  final String currency;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProductListTile({
    required this.product,
    this.category,
    required this.currency,
    required this.fmt,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: product.imageUrl.isNotEmpty
            ? Image.network(product.imageUrl, width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder())
            : _placeholder(),
      ),
      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Row(children: [
        if (category != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Color(int.parse(category!.color.replaceAll('#', '0xFF'))).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(category!.name, style: TextStyle(fontSize: 10, color: Color(int.parse(category!.color.replaceAll('#', '0xFF'))))),
          ),
          const SizedBox(width: 6),
        ],
        Text('${product.variants.length} variant${product.variants.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        if (product.isLowStock) ...[
          const SizedBox(width: 6),
          const StatusChip(label: 'Low Stock', color: AppColors.warning),
        ],
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$currency ${fmt.format(product.defaultPrice)}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 14)),
        Text(product.isAvailable ? 'Available' : 'Unavailable',
            style: TextStyle(fontSize: 11, color: product.isAvailable ? AppColors.secondary : AppColors.danger)),
      ]),
      onTap: onTap,
      onLongPress: onDelete,
    );
  }

  Widget _placeholder() {
    return Container(
      width: 48, height: 48,
      color: AppColors.primaryLight,
      child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 24),
    );
  }
}

class _LowStockBanner extends StatelessWidget {
  final int count;
  const _LowStockBanner({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
        const SizedBox(width: 8),
        Text('$count product(s) low on stock', style: const TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─── CATEGORIES TAB ──────────────────────────
class _CategoriesTab extends StatelessWidget {
  final void Function(Category) onEdit;
  const _CategoriesTab({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final categories = inventory.categories;

    if (categories.isEmpty) {
      return EmptyState(
        icon: Icons.category_outlined,
        title: 'No Categories',
        subtitle: 'Organise products with categories.',
        actionLabel: 'Add Category',
        onAction: () => showDialog(context: context, builder: (_) => const CategoryFormDialog(category: null)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final cat = categories[i];
        final color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
        final productCount = inventory.allProducts.where((p) => p.categoryId == cat.id).length;

        return Card(
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.category, color: color, size: 20),
            ),
            title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('$productCount products', style: const TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
              onPressed: () => onEdit(cat),
            ),
          ),
        );
      },
    );
  }
}

// ─── SETTINGS TAB ────────────────────────────
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(title: 'Tax Rates'),
        const SizedBox(height: 8),
        ...inventory.taxRates.map((t) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.percent, color: AppColors.primary),
            title: Text(t.name),
            subtitle: Text('${t.rate}% — ${t.inclusive ? 'Inclusive' : 'Exclusive'}'),
          ),
        )),
        OutlinedButton.icon(
          onPressed: () => _showTaxDialog(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Tax Rate'),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Discounts'),
        const SizedBox(height: 8),
        ...inventory.discounts.map((d) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.local_offer_outlined, color: AppColors.primary),
            title: Text(d.name),
            subtitle: Text(d.type == 'percentage' ? '${d.value}% off' : 'Fixed ${d.value} off'),
          ),
        )),
        OutlinedButton.icon(
          onPressed: () => _showDiscountDialog(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Discount'),
        ),
      ],
    );
  }

  void _showTaxDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _TaxRateDialog());
  }

  void _showDiscountDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _DiscountDialog());
  }
}

class _TaxRateDialog extends StatefulWidget {
  const _TaxRateDialog();
  @override
  State<_TaxRateDialog> createState() => _TaxRateDialogState();
}

class _TaxRateDialogState extends State<_TaxRateDialog> {
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  bool _inclusive = false;

  @override
  void dispose() { _nameCtrl.dispose(); _rateCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final storeId = context.read<AuthProvider>().storeId;
    final inventory = context.read<InventoryProvider>();
    final rate = TaxRate(
      id: '',
      name: _nameCtrl.text.trim(),
      rate: double.tryParse(_rateCtrl.text) ?? 0,
      inclusive: _inclusive,
    );
    await inventory.saveTaxRate(storeId, rate);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Tax Rate'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        AppTextField(controller: _nameCtrl, label: 'Name (e.g. VAT 16%)', textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        AppTextField(controller: _rateCtrl, label: 'Rate (%)', keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        SwitchListTile(value: _inclusive, onChanged: (v) => setState(() => _inclusive = v), title: const Text('Tax inclusive in price'), dense: true, contentPadding: EdgeInsets.zero),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog();
  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  final _nameCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  String _type = 'percentage';

  @override
  void dispose() { _nameCtrl.dispose(); _valueCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final storeId = context.read<AuthProvider>().storeId;
    final inventory = context.read<InventoryProvider>();
    final d = Discount(id: '', name: _nameCtrl.text.trim(), type: _type, value: double.tryParse(_valueCtrl.text) ?? 0);
    await inventory.saveDiscount(storeId, d);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Discount'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        AppTextField(controller: _nameCtrl, label: 'Name', textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: RadioListTile<String>(title: const Text('Percentage'), value: 'percentage', groupValue: _type, onChanged: (v) => setState(() => _type = v!), dense: true, contentPadding: EdgeInsets.zero)),
          Expanded(child: RadioListTile<String>(title: const Text('Fixed'), value: 'fixed', groupValue: _type, onChanged: (v) => setState(() => _type = v!), dense: true, contentPadding: EdgeInsets.zero)),
        ]),
        AppTextField(controller: _valueCtrl, label: _type == 'percentage' ? 'Percentage (%)' : 'Fixed Amount', keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// ─── CATEGORY FORM DIALOG ────────────────────
class CategoryFormDialog extends StatefulWidget {
  final Category? category;
  const CategoryFormDialog({super.key, this.category});
  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _nameCtrl = TextEditingController();
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.category?.name ?? '';
    _selectedColor = widget.category?.color ?? '#2196F3';
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final storeId = context.read<AuthProvider>().storeId;
    final cat = Category(
      id: widget.category?.id ?? '',
      name: _nameCtrl.text.trim(),
      color: _selectedColor,
      createdAt: widget.category?.createdAt ?? DateTime.now(),
    );
    await context.read<InventoryProvider>().saveCategory(storeId, cat);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.categoryColors.map((c) => '#${c.value.toRadixString(16).substring(2).toUpperCase()}').toList();
    return AlertDialog(
      title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        AppTextField(controller: _nameCtrl, label: 'Category Name', prefixIcon: Icons.category_outlined),
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft, child: Text('Color', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: AppColors.categoryColors.asMap().entries.map((e) {
            final colorHex = '#${e.value.value.toRadixString(16).substring(2).toUpperCase()}';
            final isSelected = _selectedColor == colorHex;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = colorHex),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: e.value,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
              ),
            );
          }).toList(),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// ─── PRODUCT FORM SCREEN ─────────────────────
class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fb = FirebaseService();
  final _uuid = const Uuid();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late String _selectedCategoryId;
  late String _selectedTaxRateId;
  late bool _isAvailable;
  late List<_VariantForm> _variants;
  String _imageUrl = '';
  File? _imageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl.text = p?.name ?? '';
    _descCtrl.text = p?.description ?? '';
    _selectedCategoryId = p?.categoryId ?? '';
    _selectedTaxRateId = p?.taxRateId ?? '';
    _isAvailable = p?.isAvailable ?? true;
    _imageUrl = p?.imageUrl ?? '';
    _variants = p != null
        ? p.variants.map((v) => _VariantForm.fromVariant(v)).toList()
        : [_VariantForm.empty(_uuid.v4())];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final v in _variants) v.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final storeId = context.read<AuthProvider>().storeId;
    final inventory = context.read<InventoryProvider>();

    try {
      String imageUrl = _imageUrl;

      // Upload new image if selected
      if (_imageFile != null) {
        final productId = widget.product?.id ?? _uuid.v4();
        imageUrl = await _fb.uploadProductImage(storeId, _imageFile!, productId);
      }

      final variants = _variants.map((v) => ProductVariant(
        id: v.id,
        name: v.nameCtrl.text.trim().isEmpty ? 'Default' : v.nameCtrl.text.trim(),
        price: double.tryParse(v.priceCtrl.text) ?? 0,
        cost: double.tryParse(v.costCtrl.text) ?? 0,
        sku: v.skuCtrl.text.trim(),
        barcode: v.barcodeCtrl.text.trim(),
        stock: double.tryParse(v.stockCtrl.text) ?? 0,
        lowStockAlert: double.tryParse(v.lowStockCtrl.text) ?? 5,
        trackStock: v.trackStock,
      )).toList();

      final product = Product(
        id: widget.product?.id ?? '',
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        categoryId: _selectedCategoryId,
        imageUrl: imageUrl,
        variants: variants,
        taxRateId: _selectedTaxRateId,
        isAvailable: _isAvailable,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        storeId: storeId,
      );

      await inventory.saveProduct(storeId, product);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final isNew = widget.product == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New Product' : 'Edit Product'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(onPressed: _save, child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Image
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_imageFile!, fit: BoxFit.cover))
                      : _imageUrl.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_imageUrl, fit: BoxFit.cover))
                          : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.textTertiary),
                              SizedBox(height: 4),
                              Text('Add Image', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            ]),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Basic info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Product Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _nameCtrl,
                    label: 'Product Name *',
                    prefixIcon: Icons.shopping_bag_outlined,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _descCtrl,
                    label: 'Description',
                    prefixIcon: Icons.notes_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  // Category
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId.isEmpty ? null : _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined, size: 20)),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('No Category')),
                      ...inventory.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setState(() => _selectedCategoryId = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  // Tax
                  DropdownButtonFormField<String>(
                    value: _selectedTaxRateId.isEmpty ? null : _selectedTaxRateId,
                    decoration: const InputDecoration(labelText: 'Tax Rate', prefixIcon: Icon(Icons.percent, size: 20)),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('No Tax')),
                      ...inventory.taxRates.map((t) => DropdownMenuItem(value: t.id, child: Text('${t.name} (${t.rate}%)'))),
                    ],
                    onChanged: (v) => setState(() => _selectedTaxRateId = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _isAvailable,
                    onChanged: (v) => setState(() => _isAvailable = v),
                    title: const Text('Available for sale'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Variants
            Row(children: [
              const Text('Variants', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _variants.add(_VariantForm.empty(_uuid.v4()))),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Variant'),
              ),
            ]),
            const SizedBox(height: 8),
            ..._variants.asMap().entries.map((e) => _VariantFormCard(
              form: e.value,
              index: e.key,
              canDelete: _variants.length > 1,
              onDelete: () => setState(() => _variants.removeAt(e.key)),
              onChanged: () => setState(() {}),
            )),
          ]),
        ),
      ),
    );
  }
}

class _VariantForm {
  String id;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController costCtrl;
  final TextEditingController skuCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController lowStockCtrl;
  bool trackStock;

  _VariantForm({required this.id, required this.nameCtrl, required this.priceCtrl, required this.costCtrl, required this.skuCtrl, required this.barcodeCtrl, required this.stockCtrl, required this.lowStockCtrl, required this.trackStock});

  factory _VariantForm.empty(String id) => _VariantForm(
    id: id,
    nameCtrl: TextEditingController(text: 'Default'),
    priceCtrl: TextEditingController(),
    costCtrl: TextEditingController(),
    skuCtrl: TextEditingController(),
    barcodeCtrl: TextEditingController(),
    stockCtrl: TextEditingController(text: '0'),
    lowStockCtrl: TextEditingController(text: '5'),
    trackStock: true,
  );

  factory _VariantForm.fromVariant(ProductVariant v) => _VariantForm(
    id: v.id,
    nameCtrl: TextEditingController(text: v.name),
    priceCtrl: TextEditingController(text: v.price.toString()),
    costCtrl: TextEditingController(text: v.cost.toString()),
    skuCtrl: TextEditingController(text: v.sku),
    barcodeCtrl: TextEditingController(text: v.barcode),
    stockCtrl: TextEditingController(text: v.stock.toString()),
    lowStockCtrl: TextEditingController(text: v.lowStockAlert.toString()),
    trackStock: v.trackStock,
  );

  void dispose() { nameCtrl.dispose(); priceCtrl.dispose(); costCtrl.dispose(); skuCtrl.dispose(); barcodeCtrl.dispose(); stockCtrl.dispose(); lowStockCtrl.dispose(); }
}

class _VariantFormCard extends StatefulWidget {
  final _VariantForm form;
  final int index;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  const _VariantFormCard({required this.form, required this.index, required this.canDelete, required this.onDelete, required this.onChanged});
  @override
  State<_VariantFormCard> createState() => _VariantFormCardState();
}

class _VariantFormCardState extends State<_VariantFormCard> {
  @override
  Widget build(BuildContext context) {
    final f = widget.form;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Variant ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            if (widget.canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                onPressed: widget.onDelete,
              ),
          ]),
          const SizedBox(height: 10),
          AppTextField(controller: f.nameCtrl, label: 'Variant Name', textInputAction: TextInputAction.next),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: AppTextField(controller: f.priceCtrl, label: 'Selling Price *', keyboardType: TextInputType.number, textInputAction: TextInputAction.next,
              validator: (v) => v == null || double.tryParse(v) == null ? 'Invalid' : null)),
            const SizedBox(width: 10),
            Expanded(child: AppTextField(controller: f.costCtrl, label: 'Cost Price', keyboardType: TextInputType.number, textInputAction: TextInputAction.next)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: AppTextField(controller: f.skuCtrl, label: 'SKU', textInputAction: TextInputAction.next)),
            const SizedBox(width: 10),
            Expanded(child: AppTextField(controller: f.barcodeCtrl, label: 'Barcode', keyboardType: TextInputType.number, textInputAction: TextInputAction.next)),
          ]),
          const SizedBox(height: 10),
          SwitchListTile(
            value: f.trackStock,
            onChanged: (v) { setState(() => f.trackStock = v); widget.onChanged(); },
            title: const Text('Track stock', style: TextStyle(fontSize: 13)),
            dense: true, contentPadding: EdgeInsets.zero,
          ),
          if (f.trackStock) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: AppTextField(controller: f.stockCtrl, label: 'Current Stock', keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: AppTextField(controller: f.lowStockCtrl, label: 'Low Stock Alert', keyboardType: TextInputType.number)),
            ]),
          ],
        ]),
      ),
    );
  }
}
