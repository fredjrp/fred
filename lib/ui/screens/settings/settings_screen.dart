// lib/ui/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/firebase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _fb = FirebaseService();
  Map<String, dynamic> _config = {};
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final _storeNameCtrl = TextEditingController();
  final _currencySymCtrl = TextEditingController();
  final _currencyCodeCtrl = TextEditingController();
  final _receiptHeaderCtrl = TextEditingController();
  final _receiptFooterCtrl = TextEditingController();
  final _loyaltyPtsCtrl = TextEditingController();
  final _loyaltyRateCtrl = TextEditingController();
  bool _taxEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _currencySymCtrl.dispose();
    _currencyCodeCtrl.dispose();
    _receiptHeaderCtrl.dispose();
    _receiptFooterCtrl.dispose();
    _loyaltyPtsCtrl.dispose();
    _loyaltyRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final storeId = context.read<AuthProvider>().storeId;
    if (storeId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    final config = await _fb.fetchStoreConfig(storeId);
    if (mounted) {
      setState(() {
        _config = config;
        _storeNameCtrl.text = config['name'] as String? ?? '';
        _currencySymCtrl.text = config['currencySymbol'] as String? ?? 'KSh';
        _currencyCodeCtrl.text = config['currency'] as String? ?? 'KES';
        _receiptHeaderCtrl.text = config['receiptHeader'] as String? ?? '';
        _receiptFooterCtrl.text =
            config['receiptFooter'] as String? ?? 'Thank you for your business!';
        _loyaltyPtsCtrl.text =
            (config['loyaltyPointsPerUnit'] as num?)?.toString() ?? '1';
        _loyaltyRateCtrl.text =
            (config['loyaltyRedemptionRate'] as num?)?.toString() ?? '100';
        _taxEnabled = config['taxEnabled'] as bool? ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final storeId = context.read<AuthProvider>().storeId;

    await _fb.saveStoreConfig(storeId, {
      'name': _storeNameCtrl.text.trim(),
      'currencySymbol': _currencySymCtrl.text.trim(),
      'currency': _currencyCodeCtrl.text.trim(),
      'receiptHeader': _receiptHeaderCtrl.text.trim(),
      'receiptFooter': _receiptFooterCtrl.text.trim(),
      'loyaltyPointsPerUnit':
          double.tryParse(_loyaltyPtsCtrl.text) ?? 1.0,
      'loyaltyRedemptionRate':
          double.tryParse(_loyaltyRateCtrl.text) ?? 100.0,
      'taxEnabled': _taxEnabled,
    });

    // Update local cache
    final local = context.read<AuthProvider>();
    // Re-load auth to refresh currency
    await local.initialize();

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Settings saved'),
        backgroundColor: AppColors.secondary,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Store info
          _SectionCard(
            title: 'Store Information',
            icon: Icons.store_outlined,
            children: [
              AppTextField(
                controller: _storeNameCtrl,
                label: 'Store Name',
                prefixIcon: Icons.store_outlined,
                textInputAction: TextInputAction.next,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Currency
          _SectionCard(
            title: 'Currency',
            icon: Icons.attach_money,
            children: [
              Row(children: [
                Expanded(
                  child: AppTextField(
                    controller: _currencySymCtrl,
                    label: 'Currency Symbol',
                    hint: 'e.g. KSh, \$, €',
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _currencyCodeCtrl,
                    label: 'Currency Code',
                    hint: 'e.g. KES, USD',
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),

          // Receipt
          _SectionCard(
            title: 'Receipt Customisation',
            icon: Icons.receipt_outlined,
            children: [
              AppTextField(
                controller: _receiptHeaderCtrl,
                label: 'Receipt Header',
                hint: 'Tagline, address, phone...',
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _receiptFooterCtrl,
                label: 'Receipt Footer',
                hint: 'Thank you message...',
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tax
          _SectionCard(
            title: 'Taxation',
            icon: Icons.percent,
            children: [
              SwitchListTile(
                value: _taxEnabled,
                onChanged: (v) => setState(() => _taxEnabled = v),
                title: const Text('Enable tax on sales'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Loyalty
          _SectionCard(
            title: 'Loyalty Programme',
            icon: Icons.stars_outlined,
            children: [
              const Text(
                'Configure how customers earn and redeem points.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: AppTextField(
                    controller: _loyaltyPtsCtrl,
                    label: 'Points per 1 currency unit',
                    hint: 'e.g. 1',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _loyaltyRateCtrl,
                    label: 'Points to redeem 1 unit',
                    hint: 'e.g. 100',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                'Example: ${_loyaltyPtsCtrl.text.isEmpty ? '1' : _loyaltyPtsCtrl.text} point(s) earned per '
                '${_currencySymCtrl.text.isEmpty ? 'KSh' : _currencySymCtrl.text} 1 spent. '
                '${_loyaltyRateCtrl.text.isEmpty ? '100' : _loyaltyRateCtrl.text} points = '
                '${_currencySymCtrl.text.isEmpty ? 'KSh' : _currencySymCtrl.text} 1 discount.',
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Account
          _SectionCard(
            title: 'Account',
            icon: Icons.manage_accounts_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(user?.initials ?? '?',
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
                title: Text(user?.displayName ?? ''),
                subtitle: Text(user?.email ?? ''),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user?.role.toUpperCase() ?? '',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Divider(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await context.read<AuthProvider>().signOut();
                    }
                  },
                  icon: const Icon(Icons.logout, color: AppColors.danger),
                  label: const Text('Sign Out',
                      style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sync
          _SectionCard(
            title: 'Data & Sync',
            icon: Icons.sync,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_sync_outlined,
                    color: AppColors.primary),
                title: const Text('Sync Now'),
                subtitle: const Text('Pull latest data from the cloud'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final storeId = auth.storeId;
                  final inventory = context.read<InventoryProvider>();
                  final customers = context.read<CustomerProvider>();
                  await inventory.syncFromFirebase(storeId);
                  await customers.syncFromFirebase(storeId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sync complete')));
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 16),
          // App version
          Center(
            child: Text(
              'LoyversePOS v1.0.0',
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      ),
    );
  }
}
