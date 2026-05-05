// lib/ui/screens/sales/sales_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../services/print_service.dart';
import '../../../services/firebase_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeId = context.read<AuthProvider>().storeId;
      context.read<TransactionProvider>().fetchFromFirebase(storeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final currency = context.watch<AuthProvider>().currency;
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('HH:mm');
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sales History'),
        actions: [
          // Pending sync badge
          if (txProvider.pendingSyncCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: () async {
                  final storeId = context.read<AuthProvider>().storeId;
                  final n = await txProvider.syncPending(storeId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Synced $n transactions'),
                      backgroundColor: AppColors.secondary,
                    ));
                  }
                },
                icon: const Icon(Icons.sync, size: 16, color: AppColors.warning),
                label: Text(
                  '${txProvider.pendingSyncCount} pending',
                  style: const TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ),
            ),
          // Date filter
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () => _pickDateRange(context, txProvider),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              final storeId = context.read<AuthProvider>().storeId;
              txProvider.fetchFromFirebase(storeId);
            },
          ),
        ],
      ),
      body: Column(children: [
        // Summary bar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: _SummaryPill(
                label: 'Revenue',
                value: '$currency ${fmt.format(txProvider.totalRevenue)}',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryPill(
                label: 'Transactions',
                value: txProvider.transactionCount.toString(),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryPill(
                label: 'Avg. Sale',
                value: txProvider.transactionCount > 0
                    ? '$currency ${fmt.format(txProvider.totalRevenue / txProvider.transactionCount)}'
                    : '$currency 0.00',
                color: AppColors.warning,
              ),
            ),
          ]),
        ),
        // Date range label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              '${dateFmt.format(txProvider.filterFrom)} – ${dateFmt.format(txProvider.filterTo)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ]),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: txProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : txProvider.transactions.isEmpty
                  ? const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No Transactions',
                      subtitle: 'Sales will appear here after checkout.',
                    )
                  : ListView.separated(
                      itemCount: txProvider.transactions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final tx = txProvider.transactions[i];
                        return _TransactionTile(
                          tx: tx,
                          currency: currency,
                          fmt: fmt,
                          timeFmt: timeFmt,
                          dateFmt: dateFmt,
                          onTap: () => _openDetail(context, tx),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Future<void> _pickDateRange(
      BuildContext context, TransactionProvider provider) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: provider.filterFrom,
        end: provider.filterTo,
      ),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && context.mounted) {
      provider.setDateRange(picked.start, picked.end);
      final storeId = context.read<AuthProvider>().storeId;
      provider.fetchFromFirebase(storeId);
    }
  }

  void _openDetail(BuildContext context, Transaction tx) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(tx: tx)),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  final String currency;
  final NumberFormat fmt;
  final DateFormat timeFmt;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.tx,
    required this.currency,
    required this.fmt,
    required this.timeFmt,
    required this.dateFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isVoid = tx.status == 'void';
    final isRefund = tx.status == 'refunded';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isVoid
              ? AppColors.dangerLight
              : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isVoid
              ? Icons.block_outlined
              : Icons.receipt_outlined,
          color: isVoid ? AppColors.danger : AppColors.primary,
          size: 20,
        ),
      ),
      title: Row(children: [
        Text(
          '#${tx.receiptNumber}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isVoid ? AppColors.textTertiary : AppColors.textPrimary,
            decoration: isVoid ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(width: 8),
        if (isVoid)
          StatusChip(label: 'Voided', color: AppColors.danger)
        else if (!tx.isSynced)
          StatusChip(label: 'Pending Sync', color: AppColors.warning),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 2),
        Text(
          '${dateFmt.format(tx.createdAt)} at ${timeFmt.format(tx.createdAt)} • ${tx.cashierName}',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        if (tx.customerName != null)
          Text(
            tx.customerName!,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w500),
          ),
      ]),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$currency ${fmt.format(tx.total)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isVoid ? AppColors.textTertiary : AppColors.textPrimary,
              decoration: isVoid ? TextDecoration.lineThrough : null,
            ),
          ),
          Text(
            _paymentLabel(tx.primaryPaymentMethod),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String m) {
    switch (m) {
      case 'cash': return 'Cash';
      case 'card': return 'Card';
      case 'mobile_money': return 'M-Money';
      case 'credit': return 'Credit';
      default: return m;
    }
  }
}

// ─── TRANSACTION DETAIL ──────────────────────
class TransactionDetailScreen extends StatelessWidget {
  final Transaction tx;
  const TransactionDetailScreen({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AuthProvider>().currency;
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    final printService = PrintService();
    final fb = FirebaseService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Receipt #${tx.receiptNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final config = await fb.fetchStoreConfig(auth.storeId);
              if (context.mounted) {
                await printService.printReceipt(
                  tx: tx,
                  storeName: auth.currentUser?.storeName ?? '',
                  currency: currency,
                  receiptHeader: config['receiptHeader'] as String? ?? '',
                  receiptFooter: config['receiptFooter'] as String? ?? 'Thank you!',
                );
              }
            },
            tooltip: 'Print Receipt',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              final config = await fb.fetchStoreConfig(auth.storeId);
              if (context.mounted) {
                await printService.sharePdfReceipt(
                  tx: tx,
                  storeName: auth.currentUser?.storeName ?? '',
                  currency: currency,
                  receiptHeader: config['receiptHeader'] as String? ?? '',
                  receiptFooter: config['receiptFooter'] as String? ?? 'Thank you!',
                );
              }
            },
            tooltip: 'Share PDF',
          ),
          if (tx.status == 'completed')
            IconButton(
              icon: const Icon(Icons.block_outlined, color: AppColors.danger),
              onPressed: () => _confirmVoid(context),
              tooltip: 'Void Transaction',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Status header
          if (tx.status == 'void')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.block_outlined, color: AppColors.danger, size: 18),
                SizedBox(width: 8),
                Text('This transaction has been voided',
                    style: TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w500)),
              ]),
            ),

          // Info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _InfoRow('Receipt #', tx.receiptNumber),
                _InfoRow('Date', dateFmt.format(tx.createdAt)),
                _InfoRow('Cashier', tx.cashierName),
                if (tx.customerName != null)
                  _InfoRow('Customer', tx.customerName!),
                if (tx.note != null) _InfoRow('Note', tx.note!),
                _InfoRow('Sync Status', tx.isSynced ? 'Synced ✓' : 'Pending'),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Items
          const Text('Items',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: tx.items.asMap().entries.map((e) {
                final item = e.value;
                final isLast = e.key == tx.items.length - 1;
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(item.productName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14)),
                          if (item.variantName.isNotEmpty &&
                              item.variantName != 'Default')
                            Text(item.variantName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          Text(
                              '$currency ${fmt.format(item.price)} × ${item.quantity.toInt()}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          if (item.discountAmount > 0)
                            Text(
                                'Discount: -$currency ${fmt.format(item.discountAmount)}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.danger)),
                        ]),
                      ),
                      Text('$currency ${fmt.format(item.total)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                  ),
                  if (!isLast) const Divider(height: 1),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Totals
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _TotalRow('Subtotal', '$currency ${fmt.format(tx.subtotal)}'),
                if (tx.totalDiscount > 0)
                  _TotalRow('Discount',
                      '-$currency ${fmt.format(tx.totalDiscount)}',
                      isHighlight: true,
                      color: AppColors.danger),
                if (tx.orderDiscount > 0)
                  _TotalRow('Order Discount',
                      '-$currency ${fmt.format(tx.orderDiscount)}',
                      isHighlight: true,
                      color: AppColors.danger),
                if (tx.totalTax > 0)
                  _TotalRow('Tax', '$currency ${fmt.format(tx.totalTax)}'),
                if (tx.loyaltyPointsRedeemed > 0)
                  _TotalRow(
                      'Points Redeemed',
                      '-${tx.loyaltyPointsRedeemed.toInt()} pts',
                      color: AppColors.primary),
                const Divider(height: 16),
                _TotalRow('TOTAL', '$currency ${fmt.format(tx.total)}',
                    isHighlight: true, fontSize: 16),
                const SizedBox(height: 4),
                ...tx.payments.map((p) => _TotalRow(
                      _methodLabel(p.method),
                      '$currency ${fmt.format(p.amount)}',
                    )),
                if (tx.change > 0)
                  _TotalRow(
                      'Change', '$currency ${fmt.format(tx.change)}',
                      color: AppColors.secondary),
              ]),
            ),
          ),

          // Loyalty
          if (tx.loyaltyPointsEarned > 0) ...[
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.stars, color: AppColors.primary),
                title: const Text('Loyalty Points Earned'),
                trailing: Text('+${tx.loyaltyPointsEarned.toInt()} pts',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _InfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ],
        ),
      );

  Widget _TotalRow(String label, String value,
      {bool isHighlight = false, Color? color, double fontSize = 13}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w400,
                    color: color ?? AppColors.textPrimary)),
            Text(value,
                style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                    color: color ?? AppColors.textPrimary)),
          ],
        ),
      );

  String _methodLabel(String m) {
    switch (m) {
      case 'cash': return 'Cash';
      case 'card': return 'Card';
      case 'mobile_money': return 'Mobile Money';
      case 'credit': return 'Credit';
      default: return m;
    }
  }

  void _confirmVoid(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Transaction'),
        content: const Text(
            'This will reverse the sale and restore stock. This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Void Transaction'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final storeId = context.read<AuthProvider>().storeId;
      await context.read<TransactionProvider>().voidTransaction(storeId, tx.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
