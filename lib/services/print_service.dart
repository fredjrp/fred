// lib/services/print_service.dart
// Thermal/PDF receipt generation and printing.

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

class PrintService {
  static final PrintService _instance = PrintService._internal();
  factory PrintService() => _instance;
  PrintService._internal();

  final _currencyFormat = NumberFormat('#,##0.00');

  Future<void> printReceipt({
    required Transaction tx,
    required String storeName,
    required String currency,
    String receiptHeader = '',
    String receiptFooter = 'Thank you for your business!',
    bool showTax = true,
  }) async {
    final pdf = await _buildReceiptPdf(
      tx: tx,
      storeName: storeName,
      currency: currency,
      receiptHeader: receiptHeader,
      receiptFooter: receiptFooter,
      showTax: showTax,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name: 'Receipt-${tx.receiptNumber}',
    );
  }

  Future<void> sharePdfReceipt({
    required Transaction tx,
    required String storeName,
    required String currency,
    String receiptHeader = '',
    String receiptFooter = 'Thank you for your business!',
  }) async {
    final pdf = await _buildReceiptPdf(
      tx: tx,
      storeName: storeName,
      currency: currency,
      receiptHeader: receiptHeader,
      receiptFooter: receiptFooter,
    );

    await Printing.sharePdf(
      bytes: pdf,
      filename: 'receipt-${tx.receiptNumber}.pdf',
    );
  }

  Future<Uint8List> _buildReceiptPdf({
    required Transaction tx,
    required String storeName,
    required String currency,
    String receiptHeader = '',
    String receiptFooter = '',
    bool showTax = true,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  storeName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (receiptHeader.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text(receiptHeader, style: const pw.TextStyle(fontSize: 9))),
              ],
              pw.SizedBox(height: 6),
              _divider(),

              // Receipt meta
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Receipt#', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(tx.receiptNumber, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(dateFormat.format(tx.createdAt),
                      style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cashier', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(tx.cashierName, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (tx.customerName != null) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Customer', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(tx.customerName!, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
              pw.SizedBox(height: 4),
              _divider(),

              // Column headers
              pw.Row(children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Text('Item',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  child: pw.Text('Qty',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text('Price',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text('Total',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
              ]),
              _divider(),

              // Items
              ...tx.items.map((item) {
                final displayName = item.variantName.isEmpty || item.variantName == 'Default'
                    ? item.productName
                    : '${item.productName}\n  ${item.variantName}';
                return pw.Column(
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text(displayName, style: const pw.TextStyle(fontSize: 8)),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            _qty(item.quantity),
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            _fmt(item.price),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(
                            _fmt(item.discountedSubtotal),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                    if (item.discountAmount > 0)
                      pw.Row(children: [
                        pw.Expanded(flex: 4, child: pw.Text('  Discount', style: const pw.TextStyle(fontSize: 7))),
                        pw.Expanded(child: pw.Container()),
                        pw.Expanded(flex: 4, child: pw.Text('-${_fmt(item.discountAmount)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7))),
                      ]),
                    pw.SizedBox(height: 2),
                  ],
                );
              }),
              _divider(),

              // Totals
              _totalRow('Subtotal', _fmt(tx.subtotal)),
              if (tx.totalDiscount > 0)
                _totalRow('Discount', '-${_fmt(tx.totalDiscount)}'),
              if (tx.orderDiscount > 0)
                _totalRow('Order Discount', '-${_fmt(tx.orderDiscount)}'),
              if (showTax && tx.totalTax > 0)
                _totalRow('Tax', _fmt(tx.totalTax)),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('$currency ${_fmt(tx.total)}',
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              _divider(),

              // Payments
              ...tx.payments.map((p) => _totalRow(
                    _paymentLabel(p.method),
                    '$currency ${_fmt(p.amount)}',
                  )),
              if (tx.change > 0)
                _totalRow('Change', '$currency ${_fmt(tx.change)}'),
              pw.SizedBox(height: 4),

              // Loyalty
              if (tx.loyaltyPointsEarned > 0) ...[
                _divider(),
                pw.Center(
                  child: pw.Text(
                    'Points earned: ${tx.loyaltyPointsEarned.toStringAsFixed(0)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              ],

              // Note
              if (tx.note != null && tx.note!.isNotEmpty) ...[
                _divider(),
                pw.Text('Note: ${tx.note}', style: const pw.TextStyle(fontSize: 8)),
              ],

              pw.SizedBox(height: 6),
              _divider(),

              // Footer
              if (receiptFooter.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    receiptFooter,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _divider() => pw.Column(children: [
        pw.SizedBox(height: 2),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 2),
      ]);

  pw.Widget _totalRow(String label, String value) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      );

  String _fmt(double v) => _currencyFormat.format(v);

  String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'mobile_money':
        return 'Mobile Money';
      case 'credit':
        return 'Credit';
      default:
        return method;
    }
  }
}
