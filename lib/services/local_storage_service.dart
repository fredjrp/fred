// lib/services/local_storage_service.dart
// Hive-based offline-first local storage + sync queue

import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import 'firebase_service.dart';

// Box names
const kProductsBox = 'products';
const kCategoriesBox = 'categories';
const kCustomersBox = 'customers';
const kTransactionsBox = 'transactions';
const kTaxRatesBox = 'taxRates';
const kDiscountsBox = 'discounts';
const kSyncQueueBox = 'syncQueue';
const kSettingsBox = 'settings';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  final FirebaseService _firebase = FirebaseService();

  late Box<Product> _productsBox;
  late Box<Category> _categoriesBox;
  late Box<Customer> _customersBox;
  late Box<Transaction> _transactionsBox;
  late Box<TaxRate> _taxRatesBox;
  late Box<Discount> _discountsBox;
  late Box<dynamic> _syncQueueBox;
  late Box<dynamic> _settingsBox;

  // ─── INITIALIZATION ─────────────────────────────────────
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(ProductVariantAdapter());
    Hive.registerAdapter(ProductAdapter());
    Hive.registerAdapter(CartItemAdapter());
    Hive.registerAdapter(PaymentLineAdapter());
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(AppUserAdapter());
    Hive.registerAdapter(TaxRateAdapter());
    Hive.registerAdapter(DiscountAdapter());

    // Open boxes
    await Future.wait([
      Hive.openBox<Product>(kProductsBox),
      Hive.openBox<Category>(kCategoriesBox),
      Hive.openBox<Customer>(kCustomersBox),
      Hive.openBox<Transaction>(kTransactionsBox),
      Hive.openBox<TaxRate>(kTaxRatesBox),
      Hive.openBox<Discount>(kDiscountsBox),
      Hive.openBox(kSyncQueueBox),
      Hive.openBox(kSettingsBox),
    ]);
  }

  Future<void> openBoxes() async {
    _productsBox = Hive.box<Product>(kProductsBox);
    _categoriesBox = Hive.box<Category>(kCategoriesBox);
    _customersBox = Hive.box<Customer>(kCustomersBox);
    _transactionsBox = Hive.box<Transaction>(kTransactionsBox);
    _taxRatesBox = Hive.box<TaxRate>(kTaxRatesBox);
    _discountsBox = Hive.box<Discount>(kDiscountsBox);
    _syncQueueBox = Hive.box(kSyncQueueBox);
    _settingsBox = Hive.box(kSettingsBox);
  }

  // ─── SETTINGS ───────────────────────────────────────────
  void saveString(String key, String value) => _settingsBox.put(key, value);
  String? getString(String key) => _settingsBox.get(key) as String?;
  void saveBool(String key, bool value) => _settingsBox.put(key, value);
  bool getBool(String key, {bool defaultValue = false}) =>
      (_settingsBox.get(key) as bool?) ?? defaultValue;

  // ─── PRODUCTS ───────────────────────────────────────────
  List<Product> getProducts() =>
      _productsBox.values.where((p) => !p.isDeleted).toList();

  Product? getProduct(String id) => _productsBox.get(id);

  Future<void> saveProducts(List<Product> products) async {
    final map = {for (final p in products) p.id: p};
    await _productsBox.putAll(map);
  }

  Future<void> saveProduct(Product product) async {
    await _productsBox.put(product.id, product);
  }

  Future<void> deleteProductLocal(String id) async {
    await _productsBox.delete(id);
  }

  Product? findByBarcode(String barcode) {
    for (final product in _productsBox.values) {
      for (final v in product.variants) {
        if (v.barcode == barcode) return product;
      }
    }
    return null;
  }

  // ─── CATEGORIES ─────────────────────────────────────────
  List<Category> getCategories() =>
      _categoriesBox.values.where((c) => !c.isDeleted).toList();

  Future<void> saveCategories(List<Category> categories) async {
    final map = {for (final c in categories) c.id: c};
    await _categoriesBox.putAll(map);
  }

  Future<void> saveCategory(Category category) async {
    await _categoriesBox.put(category.id, category);
  }

  // ─── CUSTOMERS ──────────────────────────────────────────
  List<Customer> getCustomers() =>
      _customersBox.values.where((c) => !c.isDeleted).toList();

  Customer? getCustomer(String id) => _customersBox.get(id);

  Future<void> saveCustomers(List<Customer> customers) async {
    final map = {for (final c in customers) c.id: c};
    await _customersBox.putAll(map);
  }

  Future<void> saveCustomer(Customer customer) async {
    await _customersBox.put(customer.id, customer);
  }

  // ─── TRANSACTIONS ────────────────────────────────────────
  List<Transaction> getTransactions() =>
      _transactionsBox.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Transaction> getUnsyncedTransactions() =>
      _transactionsBox.values.where((t) => !t.isSynced).toList();

  Future<void> saveTransaction(Transaction tx) async {
    await _transactionsBox.put(tx.id, tx);
  }

  // ─── TAX RATES ───────────────────────────────────────────
  List<TaxRate> getTaxRates() => _taxRatesBox.values.toList();

  Future<void> saveTaxRates(List<TaxRate> rates) async {
    final map = {for (final r in rates) r.id: r};
    await _taxRatesBox.putAll(map);
  }

  TaxRate? getTaxRate(String id) => _taxRatesBox.get(id);

  // ─── DISCOUNTS ───────────────────────────────────────────
  List<Discount> getDiscounts() => _discountsBox.values.toList();

  Future<void> saveDiscounts(List<Discount> discounts) async {
    final map = {for (final d in discounts) d.id: d};
    await _discountsBox.putAll(map);
  }

  // ─── SYNC QUEUE ──────────────────────────────────────────
  void addToSyncQueue(String operation, Map<String, dynamic> data) {
    final key = '${DateTime.now().millisecondsSinceEpoch}';
    _syncQueueBox.put(key, {'op': operation, 'data': data, 'ts': key});
  }

  List<Map<String, dynamic>> getSyncQueue() {
    return _syncQueueBox.values
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<void> clearSyncQueueItem(String key) async {
    await _syncQueueBox.delete(key);
  }

  Future<void> clearSyncQueue() async {
    await _syncQueueBox.clear();
  }

  // ─── FULL SYNC FROM FIREBASE ─────────────────────────────
  Future<void> syncFromFirebase(String storeId) async {
    final results = await Future.wait([
      _firebase.fetchProducts(storeId),
      _firebase.fetchCategories(storeId),
      _firebase.fetchCustomers(storeId),
      _firebase.fetchTaxRates(storeId),
      _firebase.fetchDiscounts(storeId),
    ]);

    await saveProducts(results[0] as List<Product>);
    await saveCategories(results[1] as List<Category>);
    await saveCustomers(results[2] as List<Customer>);
    await saveTaxRates(results[3] as List<TaxRate>);
    await saveDiscounts(results[4] as List<Discount>);
  }

  // ─── PUSH UNSYNCED TRANSACTIONS ──────────────────────────
  Future<int> pushUnsyncedTransactions(String storeId) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return 0;

    final unsynced = getUnsyncedTransactions();
    int pushed = 0;

    for (final tx in unsynced) {
      try {
        await _firebase.saveTransaction(storeId, tx);

        // Mark as synced
        final synced = Transaction(
          id: tx.id,
          items: tx.items,
          payments: tx.payments,
          subtotal: tx.subtotal,
          totalDiscount: tx.totalDiscount,
          totalTax: tx.totalTax,
          total: tx.total,
          change: tx.change,
          customerId: tx.customerId,
          customerName: tx.customerName,
          createdAt: tx.createdAt,
          cashierId: tx.cashierId,
          cashierName: tx.cashierName,
          receiptNumber: tx.receiptNumber,
          status: tx.status,
          isSynced: true,
          storeId: tx.storeId,
          loyaltyPointsEarned: tx.loyaltyPointsEarned,
          loyaltyPointsRedeemed: tx.loyaltyPointsRedeemed,
          note: tx.note,
          discountId: tx.discountId,
          orderDiscount: tx.orderDiscount,
        );
        await saveTransaction(synced);
        pushed++;
      } catch (e) {
        // Leave in queue for next sync attempt
        continue;
      }
    }

    return pushed;
  }

  // ─── CLEAR ALL LOCAL DATA ─────────────────────────────────
  Future<void> clearAll() async {
    await Future.wait([
      _productsBox.clear(),
      _categoriesBox.clear(),
      _customersBox.clear(),
      _transactionsBox.clear(),
      _taxRatesBox.clear(),
      _discountsBox.clear(),
      _syncQueueBox.clear(),
    ]);
  }
}
