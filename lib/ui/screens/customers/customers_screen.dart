// lib/ui/screens/customers/customers_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeId = context.read<AuthProvider>().storeId;
      context.read<CustomerProvider>().syncFromFirebase(storeId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Customers (${provider.count})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _showCustomerForm(context, null),
            tooltip: 'Add Customer',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              final storeId = context.read<AuthProvider>().storeId;
              provider.syncFromFirebase(storeId);
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: AppSearchBar(
            hint: 'Search by name, phone, email...',
            controller: _searchCtrl,
            onChanged: provider.setSearch,
            onClear: () {
              _searchCtrl.clear();
              provider.setSearch('');
            },
          ),
        ),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.customers.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline,
                      title: 'No Customers',
                      subtitle: 'Build your customer database for loyalty rewards.',
                      actionLabel: 'Add Customer',
                      onAction: () => _showCustomerForm(context, null),
                    )
                  : ListView.separated(
                      itemCount: provider.customers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (ctx, i) {
                        final c = provider.customers[i];
                        return _CustomerTile(
                          customer: c,
                          onTap: () => _showCustomerDetail(context, c),
                          onEdit: () => _showCustomerForm(context, c),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  void _showCustomerForm(BuildContext context, Customer? customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CustomerFormSheet(customer: customer),
      ),
    );
  }

  void _showCustomerDetail(BuildContext context, Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: customer)),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _CustomerTile({
    required this.customer,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final currency = context.read<AuthProvider>().currency;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primaryLight,
        child: Text(
          customer.initials,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        customer.name,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Text(
        customer.phone.isNotEmpty ? customer.phone : customer.email,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.stars, size: 13, color: AppColors.primary),
            const SizedBox(width: 3),
            Text(
              '${customer.loyaltyPoints.toInt()} pts',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ]),
          Text(
            '$currency ${fmt.format(customer.totalSpent)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ─── CUSTOMER DETAIL ─────────────────────────
class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AuthProvider>().currency;
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: _CustomerFormSheet(customer: customer),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Profile card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(customer.initials,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 22)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(customer.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    if (customer.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.phone_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(customer.phone,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ]),
                    ],
                    if (customer.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.email_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(customer.email,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ]),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Customer since ${dateFmt.format(customer.createdAt)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              StatCard(
                title: 'Total Spent',
                value: '$currency ${fmt.format(customer.totalSpent)}',
                icon: Icons.attach_money,
                color: AppColors.secondary,
              ),
              StatCard(
                title: 'Visits',
                value: customer.visitCount.toString(),
                icon: Icons.store_outlined,
                color: AppColors.primary,
              ),
              StatCard(
                title: 'Loyalty Pts',
                value: customer.loyaltyPoints.toInt().toString(),
                icon: Icons.stars,
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Last visit
          if (customer.lastVisit != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule, color: AppColors.primary),
                title: const Text('Last Visit'),
                trailing: Text(
                  dateFmt.format(customer.lastVisit!),
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
              ),
            ),

          // Address
          if (customer.address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined,
                    color: AppColors.primary),
                title: const Text('Address'),
                subtitle: Text(customer.address),
              ),
            ),
          ],

          // Note
          if (customer.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notes_outlined, color: AppColors.primary),
                title: const Text('Note'),
                subtitle: Text(customer.note),
              ),
            ),
          ],

          // Adjust loyalty points (manager only)
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Loyalty Points',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.stars, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${customer.loyaltyPoints.toInt()} points available',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Points are earned automatically on purchases.',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ]),
            ),
          ),

          // Danger zone
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              label: const Text('Delete Customer',
                  style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
            'Delete "${customer.name}"? All their data will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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
      await context.read<CustomerProvider>().deleteCustomer(storeId, customer.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ─── CUSTOMER FORM SHEET ─────────────────────
class _CustomerFormSheet extends StatefulWidget {
  final Customer? customer;
  const _CustomerFormSheet({this.customer});

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    if (c != null) {
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone;
      _emailCtrl.text = c.email;
      _addressCtrl.text = c.address;
      _noteCtrl.text = c.note;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final storeId = context.read<AuthProvider>().storeId;
    final provider = context.read<CustomerProvider>();
    final isNew = widget.customer == null;

    final customer = Customer(
      id: widget.customer?.id ?? '',
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      loyaltyPoints: widget.customer?.loyaltyPoints ?? 0,
      totalSpent: widget.customer?.totalSpent ?? 0,
      visitCount: widget.customer?.visitCount ?? 0,
      createdAt: widget.customer?.createdAt ?? DateTime.now(),
      lastVisit: widget.customer?.lastVisit,
      storeId: storeId,
    );

    try {
      await provider.saveCustomer(storeId, customer);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.danger),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.customer == null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Text(
            isNew ? 'New Customer' : 'Edit Customer',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _nameCtrl,
            label: 'Full Name *',
            prefixIcon: Icons.person_outlined,
            textInputAction: TextInputAction.next,
            validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _phoneCtrl,
            label: 'Phone Number',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\s\(\)]'))],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _emailCtrl,
            label: 'Email Address',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _addressCtrl,
            label: 'Address',
            prefixIcon: Icons.location_on_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _noteCtrl,
            label: 'Note',
            prefixIcon: Icons.notes_outlined,
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isNew ? 'Add Customer' : 'Save Changes'),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
