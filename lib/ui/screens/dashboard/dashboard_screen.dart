// lib/ui/screens/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../../providers/providers.dart';
import '../../../services/firebase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _fb = FirebaseService();
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _topProducts = [];
  List<_DailyRevenue> _weeklyRevenue = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final storeId = context.read<AuthProvider>().storeId;
    if (storeId.isEmpty) { setState(() => _isLoading = false); return; }
    try {
      final now = DateTime.now();
      final from30 = now.subtract(const Duration(days: 30));
      final results = await Future.wait([
        _fb.fetchDailySummary(storeId, now),
        _fb.fetchTopProducts(storeId, from30, now, limit: 5),
        _buildWeekly(storeId, now),
      ]);
      if (mounted) setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _topProducts = results[1] as List<Map<String, dynamic>>;
        _weeklyRevenue = results[2] as List<_DailyRevenue>;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<_DailyRevenue>> _buildWeekly(String storeId, DateTime now) async {
    final days = <_DailyRevenue>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      try {
        final s = await _fb.fetchDailySummary(storeId, day);
        days.add(_DailyRevenue(date: day, revenue: (s['totalRevenue'] as double?) ?? 0));
      } catch (_) {
        days.add(_DailyRevenue(date: day, revenue: 0));
      }
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AuthProvider>().currency;
    final fmt = NumberFormat('#,##0.00');
    final isDesktop = Responsive.isDesktop(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final txCount = (_summary['transactionCount'] as int?) ?? 0;
    final revenue = (_summary['totalRevenue'] as double?) ?? 0;
    final discount = (_summary['totalDiscount'] as double?) ?? 0;
    final avgBasket = (_summary['averageBasket'] as double?) ?? 0;
    final payBreakdown = (_summary['paymentBreakdown'] as Map<String, dynamic>?) ?? {};

    final statCards = [
      StatCard(title: 'Total Revenue', value: '$currency ${fmt.format(revenue)}', icon: Icons.attach_money, color: AppColors.secondary),
      StatCard(title: 'Transactions', value: txCount.toString(), icon: Icons.receipt_outlined, color: AppColors.primary),
      StatCard(title: 'Avg. Basket', value: '$currency ${fmt.format(avgBasket)}', icon: Icons.shopping_cart_outlined, color: AppColors.warning),
      StatCard(title: 'Discounts', value: '$currency ${fmt.format(discount)}', icon: Icons.local_offer_outlined, color: AppColors.danger),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _load)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Today\'s Overview', style: Theme.of(context).textTheme.headlineSmall),
            Text(DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 4 : 2,
                childAspectRatio: isDesktop ? 1.8 : 1.4,
                crossAxisSpacing: 12, mainAxisSpacing: 12,
              ),
              itemCount: statCards.length,
              itemBuilder: (_, i) => statCards[i],
            ),
            const SizedBox(height: 24),
            if (isDesktop)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: _RevenueChart(weeklyData: _weeklyRevenue, currency: currency)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _TopProductsCard(products: _topProducts, currency: currency, fmt: fmt)),
              ])
            else ...[
              _RevenueChart(weeklyData: _weeklyRevenue, currency: currency),
              const SizedBox(height: 16),
              _TopProductsCard(products: _topProducts, currency: currency, fmt: fmt),
            ],
            const SizedBox(height: 16),
            if (payBreakdown.isNotEmpty)
              _PaymentBreakdownCard(breakdown: payBreakdown, currency: currency, fmt: fmt),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

class _DailyRevenue { final DateTime date; final double revenue; const _DailyRevenue({required this.date, required this.revenue}); }

class _RevenueChart extends StatelessWidget {
  final List<_DailyRevenue> weeklyData;
  final String currency;
  const _RevenueChart({required this.weeklyData, required this.currency});
  @override
  Widget build(BuildContext context) {
    if (weeklyData.isEmpty) return const SizedBox.shrink();
    final maxY = weeklyData.map((d) => d.revenue).fold(0.0, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(title: 'Revenue — Last 7 Days'),
        const SizedBox(height: 20),
        SizedBox(height: 180, child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY <= 0 ? 100 : maxY * 1.2,
          barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
              '${DateFormat('EEE').format(weeklyData[g.x].date)}\n$currency ${NumberFormat('#,##0').format(rod.toY)}',
              const TextStyle(color: Colors.white, fontSize: 11),
            ),
          )),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
              getTitlesWidget: (v, _) { final i = v.toInt(); if (i < 0 || i >= weeklyData.length) return const SizedBox.shrink(); return Text(DateFormat('EEE').format(weeklyData[i].date), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)); },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48,
              getTitlesWidget: (v, _) => Text(NumberFormat.compact().format(v), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barGroups: weeklyData.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.revenue, color: AppColors.primary, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))])).toList(),
        ))),
      ])),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final String currency;
  final NumberFormat fmt;
  const _TopProductsCard({required this.products, required this.currency, required this.fmt});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(title: 'Top Products (30 days)'),
        const SizedBox(height: 12),
        if (products.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No sales data yet', style: TextStyle(color: AppColors.textSecondary))))
        else
          ...products.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Container(width: 24, height: 24, alignment: Alignment.center,
                decoration: BoxDecoration(color: e.key < 3 ? AppColors.primary : AppColors.background, shape: BoxShape.circle),
                child: Text('${e.key+1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: e.key < 3 ? Colors.white : AppColors.textSecondary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.value['name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${(e.value['quantity'] as double).toInt()} sold', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ])),
              Text('$currency ${fmt.format(e.value['revenue'] as double)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ]),
          )),
      ])),
    );
  }
}

class _PaymentBreakdownCard extends StatelessWidget {
  final Map<String, dynamic> breakdown;
  final String currency;
  final NumberFormat fmt;
  const _PaymentBreakdownCard({required this.breakdown, required this.currency, required this.fmt});
  Color _c(String m) { switch(m){ case 'cash': return AppColors.cash; case 'card': return AppColors.card; case 'mobile_money': return AppColors.mobileMoney; default: return AppColors.credit; } }
  String _l(String m) { switch(m){ case 'cash': return 'Cash'; case 'card': return 'Card'; case 'mobile_money': return 'Mobile Money'; default: return 'Credit'; } }
  @override
  Widget build(BuildContext context) {
    final entries = breakdown.entries.toList();
    final total = entries.fold(0.0, (s, e) => s + (e.value as double));
    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader(title: 'Payment Methods'),
        const SizedBox(height: 12),
        ...entries.map((e) { final pct = total > 0 ? (e.value as double)/total : 0.0; final color = _c(e.key); return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(_l(e.key), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              const Spacer(),
              Text('$currency ${fmt.format(e.value as double)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text('${(pct*100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: pct, backgroundColor: AppColors.background, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 4, borderRadius: BorderRadius.circular(2)),
          ]),
        ); }),
      ])),
    );
  }
}
