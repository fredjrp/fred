// lib/ui/screens/pos/checkout_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../services/print_service.dart';
import '../../../services/firebase_service.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key});
  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final _printService = PrintService();
  final _fb = FirebaseService();

  final List<_PaymentEntry> _paymentEntries = [];
  bool _isProcessing = false;
  Transaction? _completedTx;
  double _loyaltyToRedeem = 0;
  Map<String, dynamic> _storeConfig = {};

  @override
  void initState() {
    super.initState();
    _addPaymentEntry('cash');
    _loadStoreConfig();
  }

  Future<void> _loadStoreConfig() async {
    final storeId = context.read<AuthProvider>().storeId;
    if (storeId.isEmpty) return;
    final config = await _fb.fetchStoreConfig(storeId);
    if (mounted) setState(() => _storeConfig = config);
  }

  void _addPaymentEntry(String method) {
    setState(() => _paymentEntries.add(_PaymentEntry(method: method)));
  }

  double get _totalPaid =>
      _paymentEntries.fold(0.0, (s, e) => s + (double.tryParse(e.controller.text) ?? 0));

  double get _cartTotal => context.read<CartProvider>().total - _loyaltyValue;
  double get _loyaltyValue {
    final rate = (_storeConfig['loyaltyRedemptionRate'] as num?)?.toDouble() ?? 100;
    return _loyaltyToRedeem / rate;
  }

  double get _change => (_totalPaid - _cartTotal).clamp(0, double.infinity);
  bool get _canCharge => _totalPaid >= _cartTotal;

  Future<void> _processPayment() async {
    if (!_canCharge) return;
    setState(() => _isProcessing = true);

    try {
      final cart = context.read<CartProvider>();
      final auth = context.read<AuthProvider>();
      final txProvider = context.read<TransactionProvider>();
      final customerProvider = context.read<CustomerProvider>();

      final payments = _paymentEntries
          .where((e) => (double.tryParse(e.controller.text) ?? 0) > 0)
          .map((e) => PaymentLine(
                method: e.method,
                amount: double.tryParse(e.controller.text) ?? 0,
              ))
          .toList();

      final pointsPerUnit =
          (_storeConfig['loyaltyPointsPerUnit'] as num?)?.toDouble() ?? 1.0;
      final redemptionRate =
          (_storeConfig['loyaltyRedemptionRate'] as num?)?.toDouble() ?? 100.0;

      if (_loyaltyToRedeem > 0 && cart.customer != null) {
        cart.redeemLoyaltyPoints(_loyaltyToRedeem, redemptionRate);
      }

      final tx = await txProvider.completeTransaction(
        cart: cart,
        auth: auth,
        customerProvider: customerProvider,
        payments: payments,
        pointsPerUnit: pointsPerUnit,
      );

      if (mounted) setState(() { _completedTx = tx; _isProcessing = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _printReceipt() async {
    if (_completedTx == null) return;
    final auth = context.read<AuthProvider>();
    await _printService.printReceipt(
      tx: _completedTx!,
      storeName: auth.currentUser?.storeName ?? 'My Store',
      currency: auth.currency,
      receiptHeader: _storeConfig['receiptHeader'] as String? ?? '',
      receiptFooter: _storeConfig['receiptFooter'] as String? ?? 'Thank you!',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_completedTx != null) return _SuccessView(tx: _completedTx!, onPrint: _printReceipt, onDone: () => Navigator.pop(context));

    final cart = context.watch<CartProvider>();
    final currency = context.watch<AuthProvider>().currency;
    final fmt = NumberFormat('#,##0.00');
    final customer = cart.customer;
    final redemptionRate = (_storeConfig['loyaltyRedemptionRate'] as num?)?.toDouble() ?? 100.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.point_of_sale, color: Colors.white),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Checkout', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Total: $currency ${fmt.format(cart.total)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Order summary
                _SummaryTile(cart: cart, currency: currency, fmt: fmt),
                const SizedBox(height: 16),

                // Loyalty points
                if (customer != null && customer.loyaltyPoints > 0) ...[
                  _LoyaltySection(
                    customer: customer,
                    redemptionRate: redemptionRate,
                    toRedeem: _loyaltyToRedeem,
                    onChanged: (v) => setState(() => _loyaltyToRedeem = v),
                    currency: currency,
                    fmt: fmt,
                  ),
                  const SizedBox(height: 16),
                ],

                // Payment methods
                const Text('Payment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 10),

                ..._paymentEntries.asMap().entries.map((entry) => _PaymentEntryRow(
                  entry: entry.value,
                  index: entry.key,
                  currency: currency,
                  onMethodChange: (m) => setState(() => entry.value.method = m),
                  onRemove: entry.key > 0 ? () => setState(() => _paymentEntries.removeAt(entry.key)) : null,
                  onAmountChanged: (_) => setState(() {}),
                  remaining: (_cartTotal - _paymentEntries.take(entry.key).fold(0.0, (s, e) => s + (double.tryParse(e.controller.text) ?? 0))).clamp(0, double.infinity),
                )),

                if (_paymentEntries.length < 3)
                  TextButton.icon(
                    onPressed: () => _addPaymentEntry('card'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Payment Method', style: TextStyle(fontSize: 12)),
                  ),

                const Divider(height: 24),

                // Change
                if (_change > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.swap_horiz, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text('Change Due:', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('$currency ${fmt.format(_change)}',
                          style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700, fontSize: 16)),
                    ]),
                  ),
              ]),
            ),
          ),

          // Charge button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_canCharge && !_isProcessing) ? _processPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canCharge ? AppColors.secondary : AppColors.divider,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _canCharge ? 'Complete Payment' : 'Amount: $currency ${fmt.format(_totalPaid)} / $currency ${fmt.format(_cartTotal)}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _canCharge ? Colors.white : AppColors.textSecondary),
                      ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── PAYMENT ENTRY ROW ───────────────────────
class _PaymentEntryRow extends StatelessWidget {
  final _PaymentEntry entry;
  final int index;
  final String currency;
  final void Function(String) onMethodChange;
  final VoidCallback? onRemove;
  final void Function(String) onAmountChanged;
  final double remaining;

  const _PaymentEntryRow({
    required this.entry,
    required this.index,
    required this.currency,
    required this.onMethodChange,
    this.onRemove,
    required this.onAmountChanged,
    required this.remaining,
  });

  static const methods = [
    ('cash', 'Cash', Icons.money),
    ('card', 'Card', Icons.credit_card),
    ('mobile_money', 'Mobile Money', Icons.phone_android),
    ('credit', 'Credit', Icons.account_balance_wallet_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        // Method dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: entry.method,
              isDense: true,
              items: methods.map((m) => DropdownMenuItem(
                value: m.$1,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(m.$3, size: 16, color: _methodColor(m.$1)),
                  const SizedBox(width: 6),
                  Text(m.$2, style: const TextStyle(fontSize: 13)),
                ]),
              )).toList(),
              onChanged: (v) => onMethodChange(v!),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Amount field
        Expanded(
          child: TextFormField(
            controller: entry.controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            onChanged: onAmountChanged,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixText: '$currency ',
              hintText: remaining > 0 ? remaining.toStringAsFixed(2) : '0.00',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onTap: () {
              // Auto-fill remaining on tap if empty
              if (entry.controller.text.isEmpty && remaining > 0) {
                entry.controller.text = remaining.toStringAsFixed(2);
                onAmountChanged(entry.controller.text);
              }
            },
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 18),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
          ),
        ],
      ]),
    );
  }

  Color _methodColor(String m) {
    switch (m) {
      case 'cash': return AppColors.cash;
      case 'card': return AppColors.card;
      case 'mobile_money': return AppColors.mobileMoney;
      default: return AppColors.credit;
    }
  }
}

class _PaymentEntry {
  String method;
  final TextEditingController controller = TextEditingController();
  _PaymentEntry({required this.method});
}

// ─── SUMMARY TILE ────────────────────────────
class _SummaryTile extends StatelessWidget {
  final CartProvider cart;
  final String currency;
  final NumberFormat fmt;
  const _SummaryTile({required this.cart, required this.currency, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        _r('Items (${cart.itemCount})', '$currency ${fmt.format(cart.subtotal)}'),
        if (cart.totalDiscount > 0) _r('Discount', '-$currency ${fmt.format(cart.totalDiscount)}', color: AppColors.danger),
        if (cart.totalTax > 0) _r('Tax', '$currency ${fmt.format(cart.totalTax)}'),
        const Divider(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text('$currency ${fmt.format(cart.total)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
        ]),
      ]),
    );
  }

  Widget _r(String l, String v, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      Text(v, style: TextStyle(fontSize: 13, color: color ?? AppColors.textPrimary)),
    ]),
  );
}

// ─── LOYALTY SECTION ─────────────────────────
class _LoyaltySection extends StatefulWidget {
  final Customer customer;
  final double redemptionRate;
  final double toRedeem;
  final ValueChanged<double> onChanged;
  final String currency;
  final NumberFormat fmt;
  const _LoyaltySection({required this.customer, required this.redemptionRate, required this.toRedeem, required this.onChanged, required this.currency, required this.fmt});

  @override
  State<_LoyaltySection> createState() => _LoyaltySectionState();
}

class _LoyaltySectionState extends State<_LoyaltySection> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.toRedeem > 0 ? widget.toRedeem.toString() : '');
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final maxPoints = widget.customer.loyaltyPoints;
    final valuePerPoint = 1 / widget.redemptionRate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.stars, color: AppColors.primary, size: 18),
          const SizedBox(width: 6),
          Text('Loyalty Points: ${maxPoints.toInt()}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13)),
          const Spacer(),
          Text('${widget.currency} ${widget.fmt.format(maxPoints * valuePerPoint)} value', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                final pts = double.tryParse(v) ?? 0;
                widget.onChanged(pts.clamp(0, maxPoints));
              },
              decoration: const InputDecoration(
                hintText: 'Points to redeem',
                prefixIcon: Icon(Icons.stars, size: 16),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              _ctrl.text = maxPoints.toInt().toString();
              widget.onChanged(maxPoints);
            },
            child: const Text('Use All'),
          ),
        ]),
        if (widget.toRedeem > 0) ...[
          const SizedBox(height: 6),
          Text('Discount: ${widget.currency} ${widget.fmt.format(widget.toRedeem * valuePerPoint)}',
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
        ],
      ]),
    );
  }
}

// ─── SUCCESS VIEW ────────────────────────────
class _SuccessView extends StatelessWidget {
  final Transaction tx;
  final VoidCallback onPrint;
  final VoidCallback onDone;
  const _SuccessView({required this.tx, required this.onPrint, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final currency = context.read<AuthProvider>().currency;
    final fmt = NumberFormat('#,##0.00');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppColors.secondaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline, color: AppColors.secondary, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Payment Complete!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Receipt #${tx.receiptNumber}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('$currency ${fmt.format(tx.total)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
            if (tx.change > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: AppColors.secondaryLight, borderRadius: BorderRadius.circular(8)),
                child: Text('Change: $currency ${fmt.format(tx.change)}', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ],
            if (tx.loyaltyPointsEarned > 0) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.stars, color: AppColors.primary, size: 16),
                const SizedBox(width: 4),
                Text('+${tx.loyaltyPointsEarned.toInt()} loyalty points earned', style: const TextStyle(color: AppColors.primary, fontSize: 13)),
              ]),
            ],
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onDone,
                  child: const Text('New Sale'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
