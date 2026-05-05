// lib/providers/providers.dart
// All Provider-based state management in one barrel file.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';

// ─────────────────────────────────────────────
// AUTH PROVIDER
// ─────────────────────────────────────────────
class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final LocalStorageService _local = LocalStorageService();

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _error;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  String get storeId => _currentUser?.storeId ?? '';
  String get currency => _local.getString('currency') ?? 'KSh';
  String get currencyCode => _local.getString('currencyCode') ?? 'KES';

  Future<void> initialize() async {
    _firebase.authStateChanges.listen((user) async {
      if (user != null) {
        await _loadUserProfile();
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserProfile() async {
    _currentUser = await _firebase.fetchCurrentAppUser();
    if (_currentUser != null) {
      final config = await _firebase.fetchStoreConfig(_currentUser!.storeId);
      _local.saveString('currency', config['currencySymbol'] ?? 'KSh');
      _local.saveString('currencyCode', config['currency'] ?? 'KES');
      _local.saveString('storeName', config['name'] ?? '');
      _local.saveString('receiptHeader', config['receiptHeader'] ?? '');
      _local.saveString('receiptFooter', config['receiptFooter'] ?? '');
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebase.signIn(email, password);
      await _loadUserProfile();
      return true;
    } catch (e) {
      _error = _parseFirebaseError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
    required String storeName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cred = await _firebase.signUp(email, password);
      final storeId = await _firebase.createStore(storeName, cred.user!.uid);

      final user = AppUser(
        uid: cred.user!.uid,
        email: email,
        displayName: displayName,
        role: 'owner',
        storeId: storeId,
        storeName: storeName,
      );
      await _firebase.createOrUpdateUserProfile(user);
      await _loadUserProfile();
      return true;
    } catch (e) {
      _error = _parseFirebaseError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _firebase.signOut();
    await _local.clearAll();
    _currentUser = null;
    notifyListeners();
  }

  String _parseFirebaseError(String error) {
    if (error.contains('user-not-found')) return 'No account found with this email.';
    if (error.contains('wrong-password')) return 'Incorrect password.';
    if (error.contains('email-already-in-use')) return 'Email already in use.';
    if (error.contains('weak-password')) return 'Password is too weak.';
    if (error.contains('invalid-email')) return 'Invalid email address.';
    if (error.contains('network-request-failed')) return 'Network error. Check your connection.';
    return 'Authentication failed. Please try again.';
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────
// INVENTORY PROVIDER
// ─────────────────────────────────────────────
class InventoryProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final LocalStorageService _local = LocalStorageService();
  final _uuid = const Uuid();

  List<Product> _products = [];
  List<Category> _categories = [];
  List<TaxRate> _taxRates = [];
  List<Discount> _discounts = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedCategoryId = '';

  List<Product> get products => _filteredProducts;
  List<Product> get allProducts => _products;
  List<Category> get categories => _categories;
  List<TaxRate> get taxRates => _taxRates;
  List<Discount> get discounts => _discounts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedCategoryId => _selectedCategoryId;

  List<Product> get _filteredProducts {
    var list = _products.where((p) => p.isAvailable).toList();

    if (_selectedCategoryId.isNotEmpty) {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        if (p.name.toLowerCase().contains(q)) return true;
        for (final v in p.variants) {
          if (v.barcode.contains(q) || v.sku.toLowerCase().contains(q)) {
            return true;
          }
        }
        return false;
      }).toList();
    }

    return list;
  }

  List<Product> get lowStockProducts =>
      _products.where((p) => p.isLowStock && !p.isDeleted).toList();

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String categoryId) {
    _selectedCategoryId = categoryId == _selectedCategoryId ? '' : categoryId;
    notifyListeners();
  }

  Future<void> loadFromLocal() async {
    _products = _local.getProducts();
    _categories = _local.getCategories();
    _taxRates = _local.getTaxRates();
    _discounts = _local.getDiscounts();
    notifyListeners();
  }

  Future<void> syncFromFirebase(String storeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _local.syncFromFirebase(storeId);
      await loadFromLocal();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveProduct(String storeId, Product product) async {
    final isNew = product.id.isEmpty;
    final id = isNew ? _uuid.v4() : product.id;

    final toSave = Product(
      id: id,
      name: product.name,
      description: product.description,
      categoryId: product.categoryId,
      imageUrl: product.imageUrl,
      variants: product.variants,
      taxRateId: product.taxRateId,
      isAvailable: product.isAvailable,
      createdAt: isNew ? DateTime.now() : product.createdAt,
      updatedAt: DateTime.now(),
      isDeleted: product.isDeleted,
      storeId: storeId,
    );

    await _local.saveProduct(toSave);
    await _firebase.saveProduct(storeId, toSave);

    final idx = _products.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _products[idx] = toSave;
    } else {
      _products.add(toSave);
    }
    notifyListeners();
  }

  Future<void> deleteProduct(String storeId, String productId) async {
    await _firebase.deleteProduct(storeId, productId);
    await _local.deleteProductLocal(productId);
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
  }

  Future<void> saveCategory(String storeId, Category category) async {
    final isNew = category.id.isEmpty;
    final id = isNew ? _uuid.v4() : category.id;
    final toSave = category.copyWith(id: id);

    await _local.saveCategory(toSave);
    await _firebase.saveCategory(storeId, toSave);

    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _categories[idx] = toSave;
    } else {
      _categories.add(toSave);
    }
    notifyListeners();
  }

  Future<void> saveTaxRate(String storeId, TaxRate taxRate) async {
    await _firebase.saveTaxRate(storeId, taxRate);
    await syncFromFirebase(storeId);
  }

  Future<void> saveDiscount(String storeId, Discount discount) async {
    await _firebase.saveDiscount(storeId, discount);
    await syncFromFirebase(storeId);
  }

  Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  TaxRate? getTaxRateById(String id) {
    try {
      return _taxRates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Product? findByBarcode(String barcode) {
    final local = _local.findByBarcode(barcode);
    if (local != null) return local;
    for (final p in _products) {
      for (final v in p.variants) {
        if (v.barcode == barcode) return p;
      }
    }
    return null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────
// CART PROVIDER
// ─────────────────────────────────────────────
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  Customer? _customer;
  Discount? _orderDiscount;
  String? _note;
  double _loyaltyPointsToRedeem = 0;
  double _pointsValue = 0; // monetary value of redeemed points

  List<CartItem> get items => List.unmodifiable(_items);
  Customer? get customer => _customer;
  Discount? get orderDiscount => _orderDiscount;
  String? get note => _note;
  double get loyaltyPointsToRedeem => _loyaltyPointsToRedeem;
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity.round());

  double get subtotal => _items.fold(0, (sum, i) => sum + i.subtotal);

  double get totalItemDiscounts =>
      _items.fold(0, (sum, i) => sum + i.discountAmount);

  double get orderDiscountAmount {
    if (_orderDiscount == null) return 0;
    final discountableAmount = subtotal - totalItemDiscounts;
    return _orderDiscount!.apply(discountableAmount);
  }

  double get totalDiscount => totalItemDiscounts + orderDiscountAmount;

  double get subtotalAfterDiscounts => subtotal - totalDiscount;

  double get totalTax => _items.fold(0, (sum, i) => sum + i.taxAmount);

  double get total =>
      (subtotalAfterDiscounts + totalTax - _pointsValue).clamp(0, double.infinity);

  double get change => 0; // computed at payment time

  void addItem(Product product, ProductVariant variant, TaxRate? taxRate) {
    final existingIdx = _items.indexWhere(
        (i) => i.productId == product.id && i.variantId == variant.id);

    if (existingIdx >= 0) {
      _items[existingIdx] = _items[existingIdx]
          .copyWith(quantity: _items[existingIdx].quantity + 1);
    } else {
      _items.add(CartItem(
        productId: product.id,
        productName: product.name,
        variantId: variant.id,
        variantName: variant.name,
        price: variant.price,
        imageUrl: product.imageUrl,
        taxRateId: taxRate?.id ?? '',
        taxRate: taxRate != null ? taxRate.rate / 100 : 0,
      ));
    }
    notifyListeners();
  }

  void updateQuantity(int index, double qty) {
    if (qty <= 0) {
      removeItem(index);
      return;
    }
    _items[index] = _items[index].copyWith(quantity: qty);
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void applyItemDiscount(int index, Discount discount) {
    final item = _items[index];
    final amount = discount.apply(item.subtotal);
    _items[index] = item.copyWith(
      discountId: discount.id,
      discountAmount: amount,
    );
    notifyListeners();
  }

  void removeItemDiscount(int index) {
    _items[index] = _items[index].copyWith(discountAmount: 0, discountId: '');
    notifyListeners();
  }

  void setOrderDiscount(Discount? discount) {
    _orderDiscount = discount;
    notifyListeners();
  }

  void setCustomer(Customer? customer) {
    _customer = customer;
    _loyaltyPointsToRedeem = 0;
    _pointsValue = 0;
    notifyListeners();
  }

  void redeemLoyaltyPoints(double points, double redemptionRate) {
    // redemptionRate: points needed per 1 currency unit
    _loyaltyPointsToRedeem = points;
    _pointsValue = points / redemptionRate;
    notifyListeners();
  }

  void clearLoyaltyRedemption() {
    _loyaltyPointsToRedeem = 0;
    _pointsValue = 0;
    notifyListeners();
  }

  void setNote(String? note) {
    _note = note?.isEmpty == true ? null : note;
    notifyListeners();
  }

  double computeChange(List<PaymentLine> payments) {
    final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
    return (totalPaid - total).clamp(0, double.infinity);
  }

  double computeLoyaltyPointsEarned(double pointsPerUnit) {
    return (total * pointsPerUnit).floorToDouble();
  }

  Transaction buildTransaction({
    required String id,
    required String cashierId,
    required String cashierName,
    required String receiptNumber,
    required String storeId,
    required List<PaymentLine> payments,
    required double pointsPerUnit,
  }) {
    final txChange = computeChange(payments);
    final pointsEarned = computeLoyaltyPointsEarned(pointsPerUnit);

    return Transaction(
      id: id,
      items: List.from(_items),
      payments: payments,
      subtotal: subtotal,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      total: total,
      change: txChange,
      customerId: _customer?.id,
      customerName: _customer?.name,
      createdAt: DateTime.now(),
      cashierId: cashierId,
      cashierName: cashierName,
      receiptNumber: receiptNumber,
      status: 'completed',
      isSynced: false,
      storeId: storeId,
      loyaltyPointsEarned: pointsEarned,
      loyaltyPointsRedeemed: _loyaltyPointsToRedeem,
      note: _note,
      discountId: _orderDiscount?.id,
      orderDiscount: orderDiscountAmount,
    );
  }

  void clear() {
    _items.clear();
    _customer = null;
    _orderDiscount = null;
    _note = null;
    _loyaltyPointsToRedeem = 0;
    _pointsValue = 0;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────
// CUSTOMER PROVIDER
// ─────────────────────────────────────────────
class CustomerProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final LocalStorageService _local = LocalStorageService();
  final _uuid = const Uuid();

  List<Customer> _customers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Customer> get customers => _filtered;
  bool get isLoading => _isLoading;
  int get count => _customers.length;

  List<Customer> get _filtered {
    if (_searchQuery.isEmpty) return _customers;
    final q = _searchQuery.toLowerCase();
    return _customers.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.email.toLowerCase().contains(q);
    }).toList();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadFromLocal() async {
    _customers = _local.getCustomers();
    notifyListeners();
  }

  Future<void> syncFromFirebase(String storeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final customers = await _firebase.fetchCustomers(storeId);
      await _local.saveCustomers(customers);
      _customers = customers;
    } catch (_) {
      _customers = _local.getCustomers();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Customer> saveCustomer(String storeId, Customer customer) async {
    final isNew = customer.id.isEmpty;
    final id = isNew ? _uuid.v4() : customer.id;
    final toSave = Customer(
      id: id,
      name: customer.name,
      email: customer.email,
      phone: customer.phone,
      loyaltyPoints: customer.loyaltyPoints,
      totalSpent: customer.totalSpent,
      visitCount: customer.visitCount,
      createdAt: isNew ? DateTime.now() : customer.createdAt,
      lastVisit: customer.lastVisit,
      note: customer.note,
      storeId: storeId,
      address: customer.address,
    );

    await _local.saveCustomer(toSave);
    await _firebase.saveCustomer(storeId, toSave);

    final idx = _customers.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _customers[idx] = toSave;
    } else {
      _customers.add(toSave);
    }
    notifyListeners();
    return toSave;
  }

  Future<void> deleteCustomer(String storeId, String customerId) async {
    await _firebase.deleteCustomer(storeId, customerId);
    _customers.removeWhere((c) => c.id == customerId);
    notifyListeners();
  }

  Future<void> updateAfterSale(
    String storeId,
    String customerId,
    double saleTotal,
    double pointsEarned,
    double pointsRedeemed,
  ) async {
    await _firebase.updateCustomerAfterSale(
        storeId, customerId, saleTotal, pointsEarned, pointsRedeemed);

    final idx = _customers.indexWhere((c) => c.id == customerId);
    if (idx >= 0) {
      final c = _customers[idx];
      _customers[idx] = c.copyWith(
        loyaltyPoints: c.loyaltyPoints + pointsEarned - pointsRedeemed,
        totalSpent: c.totalSpent + saleTotal,
        visitCount: c.visitCount + 1,
        lastVisit: DateTime.now(),
      );
      await _local.saveCustomer(_customers[idx]);
    }
    notifyListeners();
  }

  Customer? findById(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────
// TRANSACTION PROVIDER
// ─────────────────────────────────────────────
class TransactionProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();
  final LocalStorageService _local = LocalStorageService();
  final _uuid = const Uuid();

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  DateTime _filterFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _filterTo = DateTime.now();

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  DateTime get filterFrom => _filterFrom;
  DateTime get filterTo => _filterTo;

  double get totalRevenue =>
      _transactions.where((t) => t.status == 'completed').fold(0, (s, t) => s + t.total);

  int get transactionCount =>
      _transactions.where((t) => t.status == 'completed').length;

  void setDateRange(DateTime from, DateTime to) {
    _filterFrom = from;
    _filterTo = to;
    notifyListeners();
  }

  Future<void> loadFromLocal() async {
    _transactions = _local.getTransactions();
    notifyListeners();
  }

  Future<void> fetchFromFirebase(String storeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final txs = await _firebase.fetchTransactions(
          storeId, _filterFrom, _filterTo.add(const Duration(days: 1)));
      _transactions = txs;
      for (final tx in txs) {
        await _local.saveTransaction(tx);
      }
    } catch (_) {
      _transactions = _local.getTransactions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Transaction> completeTransaction({
    required CartProvider cart,
    required AuthProvider auth,
    required CustomerProvider customerProvider,
    required List<PaymentLine> payments,
    required double pointsPerUnit,
  }) async {
    final storeId = auth.storeId;
    final txId = _uuid.v4();

    final receiptNumber = await _generateReceiptNumber(storeId);

    final tx = cart.buildTransaction(
      id: txId,
      cashierId: auth.currentUser!.uid,
      cashierName: auth.currentUser!.displayName,
      receiptNumber: receiptNumber,
      storeId: storeId,
      payments: payments,
      pointsPerUnit: pointsPerUnit,
    );

    // Save locally first (offline-first)
    await _local.saveTransaction(tx);

    // Try to sync immediately
    final connectivity = await Connectivity().checkConnectivity();
    Transaction finalTx = tx;

    if (connectivity != ConnectivityResult.none) {
      try {
        await _firebase.saveTransaction(storeId, tx);
        // Mark as synced
        finalTx = Transaction(
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
        await _local.saveTransaction(finalTx);

        // Update customer
        if (tx.customerId != null) {
          await customerProvider.updateAfterSale(
            storeId,
            tx.customerId!,
            tx.total,
            tx.loyaltyPointsEarned,
            tx.loyaltyPointsRedeemed,
          );
        }
      } catch (_) {
        // Stay as unsynced – will sync later
      }
    }

    _transactions.insert(0, finalTx);
    cart.clear();
    notifyListeners();
    return finalTx;
  }

  Future<void> voidTransaction(String storeId, String txId) async {
    await _firebase.voidTransaction(storeId, txId);
    final idx = _transactions.indexWhere((t) => t.id == txId);
    if (idx >= 0) {
      final t = _transactions[idx];
      _transactions[idx] = Transaction(
        id: t.id,
        items: t.items,
        payments: t.payments,
        subtotal: t.subtotal,
        totalDiscount: t.totalDiscount,
        totalTax: t.totalTax,
        total: t.total,
        change: t.change,
        customerId: t.customerId,
        customerName: t.customerName,
        createdAt: t.createdAt,
        cashierId: t.cashierId,
        cashierName: t.cashierName,
        receiptNumber: t.receiptNumber,
        status: 'void',
        isSynced: true,
        storeId: t.storeId,
        loyaltyPointsEarned: 0,
        loyaltyPointsRedeemed: 0,
      );
    }
    notifyListeners();
  }

  Future<int> syncPending(String storeId) async {
    final pushed = await _local.pushUnsyncedTransactions(storeId);
    if (pushed > 0) {
      await loadFromLocal();
    }
    return pushed;
  }

  int get pendingSyncCount => _local.getUnsyncedTransactions().length;

  Future<String> _generateReceiptNumber(String storeId) async {
    try {
      return await _firebase.generateReceiptNumber(storeId);
    } catch (_) {
      final now = DateTime.now();
      return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond}';
    }
  }
}

// ─────────────────────────────────────────────
// CONNECTIVITY PROVIDER
// ─────────────────────────────────────────────
class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  StreamSubscription? _sub;

  bool get isOnline => _isOnline;

  void init() {
    Connectivity().checkConnectivity().then((result) {
      _isOnline = result != ConnectivityResult.none;
      notifyListeners();
    });

    _sub = Connectivity().onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
