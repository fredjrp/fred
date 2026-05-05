// lib/services/firebase_service.dart
// Complete Firebase service layer: Auth + Firestore + Storage

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // ─── AUTH ───────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ─── USER PROFILE ───────────────────────────────────────
  Future<AppUser?> fetchCurrentAppUser() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc);
  }

  Future<void> createOrUpdateUserProfile(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(
          user.toFirestore(),
          SetOptions(merge: true),
        );
  }

  Future<List<AppUser>> fetchStoreUsers(String storeId) async {
    final snap = await _db
        .collection('users')
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map((d) => AppUser.fromFirestore(d)).toList();
  }

  // ─── CATEGORIES ─────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _categoriesRef(String storeId) =>
      _db.collection('stores').doc(storeId).collection('categories');

  Stream<List<Category>> categoriesStream(String storeId) =>
      _categoriesRef(storeId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('name')
          .snapshots()
          .map((s) => s.docs.map((d) => Category.fromFirestore(d)).toList());

  Future<List<Category>> fetchCategories(String storeId) async {
    final snap = await _categoriesRef(storeId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('name')
        .get();
    return snap.docs.map((d) => Category.fromFirestore(d)).toList();
  }

  Future<String> saveCategory(String storeId, Category category) async {
    final ref = category.id.isEmpty
        ? _categoriesRef(storeId).doc()
        : _categoriesRef(storeId).doc(category.id);
    await ref.set(category.copyWith(id: ref.id).toFirestore(), SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deleteCategory(String storeId, String categoryId) async {
    await _categoriesRef(storeId).doc(categoryId).update({'isDeleted': true});
  }

  // ─── PRODUCTS ───────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _productsRef(String storeId) =>
      _db.collection('stores').doc(storeId).collection('products');

  Stream<List<Product>> productsStream(String storeId) =>
      _productsRef(storeId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('name')
          .snapshots()
          .map((s) => s.docs.map((d) => Product.fromFirestore(d)).toList());

  Future<List<Product>> fetchProducts(String storeId) async {
    final snap = await _productsRef(storeId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('name')
        .get();
    return snap.docs.map((d) => Product.fromFirestore(d)).toList();
  }

  Future<Product?> fetchProductByBarcode(String storeId, String barcode) async {
    final snap = await _productsRef(storeId)
        .where('isDeleted', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      final product = Product.fromFirestore(doc);
      for (final variant in product.variants) {
        if (variant.barcode == barcode) return product;
      }
    }
    return null;
  }

  Future<String> saveProduct(String storeId, Product product) async {
    final ref = product.id.isEmpty
        ? _productsRef(storeId).doc()
        : _productsRef(storeId).doc(product.id);
    final toSave = product.id.isEmpty
        ? product.copyWith()
        : product;
    await ref.set(toSave.toFirestore(), SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deleteProduct(String storeId, String productId) async {
    await _productsRef(storeId)
        .doc(productId)
        .update({'isDeleted': true, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> adjustStock(
      String storeId, String productId, String variantId, double delta) async {
    final ref = _productsRef(storeId).doc(productId);
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return;
      final product = Product.fromFirestore(doc);
      final updatedVariants = product.variants.map((v) {
        if (v.id == variantId && v.trackStock) {
          return v.copyWith(stock: (v.stock + delta).clamp(0, double.infinity));
        }
        return v;
      }).toList();
      tx.update(ref, {
        'variants': updatedVariants.map((v) => v.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ─── TAX RATES ───────────────────────────────────────────
  Future<List<TaxRate>> fetchTaxRates(String storeId) async {
    final snap = await _db
        .collection('stores')
        .doc(storeId)
        .collection('taxRates')
        .get();
    return snap.docs.map((d) => TaxRate.fromFirestore(d)).toList();
  }

  Future<String> saveTaxRate(String storeId, TaxRate taxRate) async {
    final ref = taxRate.id.isEmpty
        ? _db.collection('stores').doc(storeId).collection('taxRates').doc()
        : _db.collection('stores').doc(storeId).collection('taxRates').doc(taxRate.id);
    await ref.set(taxRate.toFirestore(), SetOptions(merge: true));
    return ref.id;
  }

  // ─── DISCOUNTS ───────────────────────────────────────────
  Future<List<Discount>> fetchDiscounts(String storeId) async {
    final snap = await _db
        .collection('stores')
        .doc(storeId)
        .collection('discounts')
        .get();
    return snap.docs.map((d) => Discount.fromFirestore(d)).toList();
  }

  Future<String> saveDiscount(String storeId, Discount discount) async {
    final ref = discount.id.isEmpty
        ? _db.collection('stores').doc(storeId).collection('discounts').doc()
        : _db.collection('stores').doc(storeId).collection('discounts').doc(discount.id);
    await ref.set(discount.toFirestore(), SetOptions(merge: true));
    return ref.id;
  }

  // ─── TRANSACTIONS ────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _transactionsRef(String storeId) =>
      _db.collection('stores').doc(storeId).collection('transactions');

  Stream<List<Transaction>> transactionsStream(
      String storeId, DateTime from, DateTime to) =>
      _transactionsRef(storeId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .where('status', isNotEqualTo: 'void')
          .orderBy('status')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map((d) => Transaction.fromFirestore(d)).toList());

  Future<List<Transaction>> fetchTransactions(
      String storeId, DateTime from, DateTime to) async {
    final snap = await _transactionsRef(storeId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => Transaction.fromFirestore(d)).toList();
  }

  Future<Transaction?> fetchTransaction(String storeId, String txId) async {
    final doc = await _transactionsRef(storeId).doc(txId).get();
    if (!doc.exists) return null;
    return Transaction.fromFirestore(doc);
  }

  Future<String> saveTransaction(String storeId, Transaction tx) async {
    final ref = tx.id.isEmpty
        ? _transactionsRef(storeId).doc(_uuid.v4())
        : _transactionsRef(storeId).doc(tx.id);
    await ref.set(tx.toFirestore());

    // Deduct stock for each item
    for (final item in tx.items) {
      if (item.quantity > 0) {
        await adjustStock(storeId, item.productId, item.variantId, -item.quantity);
      }
    }

    return ref.id;
  }

  Future<void> voidTransaction(String storeId, String txId) async {
    final ref = _transactionsRef(storeId).doc(txId);
    final doc = await ref.get();
    if (!doc.exists) return;
    final tx = Transaction.fromFirestore(doc);

    // Restore stock
    for (final item in tx.items) {
      await adjustStock(storeId, item.productId, item.variantId, item.quantity);
    }

    await ref.update({'status': 'void'});
  }

  Future<String> generateReceiptNumber(String storeId) async {
    final today = DateTime.now();
    final prefix =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';

    final snap = await _transactionsRef(storeId)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(today.year, today.month, today.day)))
        .get();

    final count = snap.docs.length + 1;
    return '$prefix-${count.toString().padLeft(4, '0')}';
  }

  // ─── CUSTOMERS ───────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _customersRef(String storeId) =>
      _db.collection('stores').doc(storeId).collection('customers');

  Stream<List<Customer>> customersStream(String storeId) =>
      _customersRef(storeId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('name')
          .snapshots()
          .map((s) => s.docs.map((d) => Customer.fromFirestore(d)).toList());

  Future<List<Customer>> fetchCustomers(String storeId) async {
    final snap = await _customersRef(storeId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('name')
        .get();
    return snap.docs.map((d) => Customer.fromFirestore(d)).toList();
  }

  Future<String> saveCustomer(String storeId, Customer customer) async {
    final ref = customer.id.isEmpty
        ? _customersRef(storeId).doc(_uuid.v4())
        : _customersRef(storeId).doc(customer.id);
    await ref.set(customer.toFirestore(), SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deleteCustomer(String storeId, String customerId) async {
    await _customersRef(storeId).doc(customerId).update({'isDeleted': true});
  }

  Future<void> updateCustomerAfterSale(
    String storeId,
    String customerId,
    double saleTotal,
    double pointsEarned,
    double pointsRedeemed,
  ) async {
    await _customersRef(storeId).doc(customerId).update({
      'totalSpent': FieldValue.increment(saleTotal),
      'visitCount': FieldValue.increment(1),
      'loyaltyPoints': FieldValue.increment(pointsEarned - pointsRedeemed),
      'lastVisit': FieldValue.serverTimestamp(),
    });
  }

  // ─── STORAGE ─────────────────────────────────────────────
  Future<String> uploadProductImage(String storeId, File file, String productId) async {
    final ref = _storage.ref('stores/$storeId/products/$productId.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<void> deleteProductImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (_) {}
  }

  // ─── STORE CONFIG ─────────────────────────────────────────
  Future<Map<String, dynamic>> fetchStoreConfig(String storeId) async {
    final doc = await _db.collection('stores').doc(storeId).get();
    if (!doc.exists) return {};
    return doc.data() ?? {};
  }

  Future<void> saveStoreConfig(String storeId, Map<String, dynamic> config) async {
    await _db.collection('stores').doc(storeId).set(config, SetOptions(merge: true));
  }

  Future<String> createStore(String name, String ownerUid) async {
    final ref = _db.collection('stores').doc();
    await ref.set({
      'name': name,
      'ownerId': ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
      'currency': 'KES',
      'currencySymbol': 'KSh',
      'loyaltyPointsPerUnit': 1.0,
      'loyaltyRedemptionRate': 100.0, // 100 points = 1 unit currency
      'taxEnabled': true,
      'receiptHeader': name,
      'receiptFooter': 'Thank you for your business!',
    });
    return ref.id;
  }

  // ─── ANALYTICS QUERIES ────────────────────────────────────
  Future<Map<String, dynamic>> fetchDailySummary(
      String storeId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final snap = await _transactionsRef(storeId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .where('status', isEqualTo: 'completed')
        .get();

    final txs = snap.docs.map((d) => Transaction.fromFirestore(d)).toList();

    double totalRevenue = 0;
    double totalTax = 0;
    double totalDiscount = 0;
    int totalItems = 0;
    final paymentBreakdown = <String, double>{};

    for (final tx in txs) {
      totalRevenue += tx.total;
      totalTax += tx.totalTax;
      totalDiscount += tx.totalDiscount + tx.orderDiscount;
      totalItems += tx.items.fold(0, (sum, i) => sum + i.quantity.round());

      for (final p in tx.payments) {
        paymentBreakdown[p.method] =
            (paymentBreakdown[p.method] ?? 0) + p.amount;
      }
    }

    return {
      'transactionCount': txs.length,
      'totalRevenue': totalRevenue,
      'totalTax': totalTax,
      'totalDiscount': totalDiscount,
      'totalItems': totalItems,
      'paymentBreakdown': paymentBreakdown,
      'averageBasket': txs.isNotEmpty ? totalRevenue / txs.length : 0,
    };
  }

  Future<List<Map<String, dynamic>>> fetchTopProducts(
      String storeId, DateTime from, DateTime to, {int limit = 10}) async {
    final snap = await _transactionsRef(storeId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .where('status', isEqualTo: 'completed')
        .get();

    final txs = snap.docs.map((d) => Transaction.fromFirestore(d)).toList();

    final productTotals = <String, Map<String, dynamic>>{};
    for (final tx in txs) {
      for (final item in tx.items) {
        final key = '${item.productId}_${item.variantId}';
        if (productTotals.containsKey(key)) {
          productTotals[key]!['quantity'] =
              (productTotals[key]!['quantity'] as double) + item.quantity;
          productTotals[key]!['revenue'] =
              (productTotals[key]!['revenue'] as double) + item.total;
        } else {
          productTotals[key] = {
            'productId': item.productId,
            'name': '${item.productName} (${item.variantName})',
            'quantity': item.quantity,
            'revenue': item.total,
          };
        }
      }
    }

    final sorted = productTotals.values.toList()
      ..sort((a, b) =>
          (b['revenue'] as double).compareTo(a['revenue'] as double));

    return sorted.take(limit).toList();
  }
}
