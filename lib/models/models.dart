// lib/models/models.dart
// Single barrel file for all domain models with Hive adapters.

import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'models.g.dart';

// ─────────────────────────────────────────────
// TYPE IDS (Hive)
// ─────────────────────────────────────────────
// Category    → 0
// ProductVariant → 1
// Product     → 2
// CartItem    → 3
// PaymentLine → 4
// Transaction → 5
// Customer    → 6
// AppUser     → 7
// TaxRate     → 8
// Discount    → 9

// ─────────────────────────────────────────────
// CATEGORY
// ─────────────────────────────────────────────
@HiveType(typeId: 0)
class Category extends HiveObject with EquatableMixin {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String color; // hex string e.g. '#FF5722'
  @HiveField(3) DateTime createdAt;
  @HiveField(4) bool isDeleted;

  Category({
    required this.id,
    required this.name,
    this.color = '#2196F3',
    required this.createdAt,
    this.isDeleted = false,
  });

  factory Category.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      name: d['name'] ?? '',
      color: d['color'] ?? '#2196F3',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: d['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'color': color,
        'createdAt': Timestamp.fromDate(createdAt),
        'isDeleted': isDeleted,
      };

  Category copyWith({String? id, String? name, String? color, bool? isDeleted}) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        createdAt: createdAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  @override
  List<Object?> get props => [id, name, color, isDeleted];
}

// ─────────────────────────────────────────────
// PRODUCT VARIANT
// ─────────────────────────────────────────────
@HiveType(typeId: 1)
class ProductVariant extends HiveObject with EquatableMixin {
  @HiveField(0) String id;
  @HiveField(1) String name;       // e.g. "Small", "Red/XL"
  @HiveField(2) double price;
  @HiveField(3) double cost;
  @HiveField(4) String sku;
  @HiveField(5) String barcode;
  @HiveField(6) double stock;
  @HiveField(7) double lowStockAlert;
  @HiveField(8) bool trackStock;

  ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    this.cost = 0,
    this.sku = '',
    this.barcode = '',
    this.stock = 0,
    this.lowStockAlert = 5,
    this.trackStock = true,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> m) => ProductVariant(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        price: (m['price'] as num?)?.toDouble() ?? 0,
        cost: (m['cost'] as num?)?.toDouble() ?? 0,
        sku: m['sku'] ?? '',
        barcode: m['barcode'] ?? '',
        stock: (m['stock'] as num?)?.toDouble() ?? 0,
        lowStockAlert: (m['lowStockAlert'] as num?)?.toDouble() ?? 5,
        trackStock: m['trackStock'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'cost': cost,
        'sku': sku,
        'barcode': barcode,
        'stock': stock,
        'lowStockAlert': lowStockAlert,
        'trackStock': trackStock,
      };

  ProductVariant copyWith({
    String? name,
    double? price,
    double? cost,
    String? sku,
    String? barcode,
    double? stock,
    double? lowStockAlert,
    bool? trackStock,
  }) =>
      ProductVariant(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        cost: cost ?? this.cost,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
        stock: stock ?? this.stock,
        lowStockAlert: lowStockAlert ?? this.lowStockAlert,
        trackStock: trackStock ?? this.trackStock,
      );

  bool get isLowStock => trackStock && stock <= lowStockAlert;

  @override
  List<Object?> get props => [id, name, price, stock];
}

// ─────────────────────────────────────────────
// PRODUCT
// ─────────────────────────────────────────────
@HiveType(typeId: 2)
class Product extends HiveObject with EquatableMixin {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String description;
  @HiveField(3) String categoryId;
  @HiveField(4) String imageUrl;
  @HiveField(5) List<ProductVariant> variants;
  @HiveField(6) String taxRateId;
  @HiveField(7) bool isAvailable;
  @HiveField(8) DateTime createdAt;
  @HiveField(9) DateTime updatedAt;
  @HiveField(10) bool isDeleted;
  @HiveField(11) String storeId;

  Product({
    required this.id,
    required this.name,
    this.description = '',
    this.categoryId = '',
    this.imageUrl = '',
    required this.variants,
    this.taxRateId = '',
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.storeId = '',
  });

  double get defaultPrice => variants.isNotEmpty ? variants.first.price : 0;
  ProductVariant? get defaultVariant => variants.isNotEmpty ? variants.first : null;
  bool get hasMultipleVariants => variants.length > 1;

  bool get isLowStock =>
      variants.any((v) => v.isLowStock);

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final variantList = (d['variants'] as List<dynamic>? ?? [])
        .map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
        .toList();
    return Product(
      id: doc.id,
      name: d['name'] ?? '',
      description: d['description'] ?? '',
      categoryId: d['categoryId'] ?? '',
      imageUrl: d['imageUrl'] ?? '',
      variants: variantList,
      taxRateId: d['taxRateId'] ?? '',
      isAvailable: d['isAvailable'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: d['isDeleted'] ?? false,
      storeId: d['storeId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'description': description,
        'categoryId': categoryId,
        'imageUrl': imageUrl,
        'variants': variants.map((v) => v.toMap()).toList(),
        'taxRateId': taxRateId,
        'isAvailable': isAvailable,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'isDeleted': isDeleted,
        'storeId': storeId,
      };

  Product copyWith({
    String? name,
    String? description,
    String? categoryId,
    String? imageUrl,
    List<ProductVariant>? variants,
    String? taxRateId,
    bool? isAvailable,
    bool? isDeleted,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        categoryId: categoryId ?? this.categoryId,
        imageUrl: imageUrl ?? this.imageUrl,
        variants: variants ?? this.variants,
        taxRateId: taxRateId ?? this.taxRateId,
        isAvailable: isAvailable ?? this.isAvailable,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        isDeleted: isDeleted ?? this.isDeleted,
        storeId: storeId,
      );

  @override
  List<Object?> get props => [id, name, isDeleted, updatedAt];
}

// ─────────────────────────────────────────────
// TAX RATE
// ─────────────────────────────────────────────
@HiveType(typeId: 8)
class TaxRate extends HiveObject with EquatableMixin {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) double rate; // percentage, e.g. 16.0 for 16%
  @HiveField(3) bool inclusive; // tax included in price or added on top

  TaxRate({
    required this.id,
    required this.name,
    required this.rate,
    this.inclusive = false,
  });

  factory TaxRate.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TaxRate(
      id: doc.id,
      name: d['name'] ?? '',
      rate: (d['rate'] as num?)?.toDouble() ?? 0,
      inclusive: d['inclusive'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'rate': rate,
        'inclusive': inclusive,
      };

  @override
  List<Object?> get props => [id, rate];
}

// ─────────────────────────────────────────────
// DISCOUNT
// ─────────────────────────────────────────────
@HiveType(typeId: 9)
class Discount extends HiveObject with EquatableMixin {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String type; // 'percentage' | 'fixed'
  @HiveField(3) double value;

  Discount({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
  });

  factory Discount.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Discount(
      id: doc.id,
      name: d['name'] ?? '',
      type: d['type'] ?? 'percentage',
      value: (d['value'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'type': type,
        'value': value,
      };

  double apply(double subtotal) {
    if (type == 'percentage') {
      return subtotal * (value / 100);
    }
    return value.clamp(0, subtotal);
  }

  @override
  List<Object?> get props => [id, type, value];
}

// ─────────────────────────────────────────────
// CART ITEM
// ─────────────────────────────────────────────
@HiveType(typeId: 3)
class CartItem extends HiveObject with EquatableMixin {
  @HiveField(0) String productId;
  @HiveField(1) String productName;
  @HiveField(2) String variantId;
  @HiveField(3) String variantName;
  @HiveField(4) double price;
  @HiveField(5) double quantity;
  @HiveField(6) String? discountId;
  @HiveField(7) double discountAmount; // computed
  @HiveField(8) String imageUrl;
  @HiveField(9) String taxRateId;
  @HiveField(10) double taxRate; // e.g. 0.16

  CartItem({
    required this.productId,
    required this.productName,
    required this.variantId,
    required this.variantName,
    required this.price,
    this.quantity = 1,
    this.discountId,
    this.discountAmount = 0,
    this.imageUrl = '',
    this.taxRateId = '',
    this.taxRate = 0,
  });

  double get subtotal => price * quantity;
  double get discountedSubtotal => subtotal - discountAmount;
  double get taxAmount => discountedSubtotal * taxRate;
  double get total => discountedSubtotal + taxAmount;

  CartItem copyWith({double? quantity, double? discountAmount, String? discountId}) =>
      CartItem(
        productId: productId,
        productName: productName,
        variantId: variantId,
        variantName: variantName,
        price: price,
        quantity: quantity ?? this.quantity,
        discountId: discountId ?? this.discountId,
        discountAmount: discountAmount ?? this.discountAmount,
        imageUrl: imageUrl,
        taxRateId: taxRateId,
        taxRate: taxRate,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'variantId': variantId,
        'variantName': variantName,
        'price': price,
        'quantity': quantity,
        'discountId': discountId,
        'discountAmount': discountAmount,
        'imageUrl': imageUrl,
        'taxRateId': taxRateId,
        'taxRate': taxRate,
        'subtotal': subtotal,
        'taxAmount': taxAmount,
        'total': total,
      };

  @override
  List<Object?> get props => [productId, variantId, quantity];
}

// ─────────────────────────────────────────────
// PAYMENT LINE
// ─────────────────────────────────────────────
@HiveType(typeId: 4)
class PaymentLine extends HiveObject {
  @HiveField(0) String method; // 'cash' | 'card' | 'mobile_money' | 'credit'
  @HiveField(1) double amount;

  PaymentLine({required this.method, required this.amount});

  Map<String, dynamic> toMap() => {'method': method, 'amount': amount};

  factory PaymentLine.fromMap(Map<String, dynamic> m) =>
      PaymentLine(method: m['method'] ?? 'cash', amount: (m['amount'] as num?)?.toDouble() ?? 0);
}

// ─────────────────────────────────────────────
// TRANSACTION (RECEIPT)
// ─────────────────────────────────────────────
@HiveType(typeId: 5)
class Transaction extends HiveObject with EquatableMixin {
  @HiveField(0) String id;
  @HiveField(1) List<CartItem> items;
  @HiveField(2) List<PaymentLine> payments;
  @HiveField(3) double subtotal;
  @HiveField(4) double totalDiscount;
  @HiveField(5) double totalTax;
  @HiveField(6) double total;
  @HiveField(7) double change;
  @HiveField(8) String? customerId;
  @HiveField(9) String? customerName;
  @HiveField(10) DateTime createdAt;
  @HiveField(11) String cashierId;
  @HiveField(12) String cashierName;
  @HiveField(13) String receiptNumber;
  @HiveField(14) String status; // 'completed' | 'refunded' | 'void' | 'pending_sync'
  @HiveField(15) bool isSynced;
  @HiveField(16) String storeId;
  @HiveField(17) double loyaltyPointsEarned;
  @HiveField(18) double loyaltyPointsRedeemed;
  @HiveField(19) String? note;
  @HiveField(20) String? discountId;
  @HiveField(21) double orderDiscount; // order-level discount amount

  Transaction({
    required this.id,
    required this.items,
    required this.payments,
    required this.subtotal,
    required this.totalDiscount,
    required this.totalTax,
    required this.total,
    this.change = 0,
    this.customerId,
    this.customerName,
    required this.createdAt,
    required this.cashierId,
    required this.cashierName,
    required this.receiptNumber,
    this.status = 'completed',
    this.isSynced = false,
    this.storeId = '',
    this.loyaltyPointsEarned = 0,
    this.loyaltyPointsRedeemed = 0,
    this.note,
    this.discountId,
    this.orderDiscount = 0,
  });

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final itemList = (d['items'] as List<dynamic>? ?? []).map((i) {
      final m = i as Map<String, dynamic>;
      return CartItem(
        productId: m['productId'] ?? '',
        productName: m['productName'] ?? '',
        variantId: m['variantId'] ?? '',
        variantName: m['variantName'] ?? '',
        price: (m['price'] as num?)?.toDouble() ?? 0,
        quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
        discountAmount: (m['discountAmount'] as num?)?.toDouble() ?? 0,
        imageUrl: m['imageUrl'] ?? '',
        taxRateId: m['taxRateId'] ?? '',
        taxRate: (m['taxRate'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    final paymentList = (d['payments'] as List<dynamic>? ?? [])
        .map((p) => PaymentLine.fromMap(p as Map<String, dynamic>))
        .toList();

    return Transaction(
      id: doc.id,
      items: itemList,
      payments: paymentList,
      subtotal: (d['subtotal'] as num?)?.toDouble() ?? 0,
      totalDiscount: (d['totalDiscount'] as num?)?.toDouble() ?? 0,
      totalTax: (d['totalTax'] as num?)?.toDouble() ?? 0,
      total: (d['total'] as num?)?.toDouble() ?? 0,
      change: (d['change'] as num?)?.toDouble() ?? 0,
      customerId: d['customerId'],
      customerName: d['customerName'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cashierId: d['cashierId'] ?? '',
      cashierName: d['cashierName'] ?? '',
      receiptNumber: d['receiptNumber'] ?? '',
      status: d['status'] ?? 'completed',
      isSynced: true,
      storeId: d['storeId'] ?? '',
      loyaltyPointsEarned: (d['loyaltyPointsEarned'] as num?)?.toDouble() ?? 0,
      loyaltyPointsRedeemed: (d['loyaltyPointsRedeemed'] as num?)?.toDouble() ?? 0,
      note: d['note'],
      discountId: d['discountId'],
      orderDiscount: (d['orderDiscount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'items': items.map((i) => i.toMap()).toList(),
        'payments': payments.map((p) => p.toMap()).toList(),
        'subtotal': subtotal,
        'totalDiscount': totalDiscount,
        'totalTax': totalTax,
        'total': total,
        'change': change,
        'customerId': customerId,
        'customerName': customerName,
        'createdAt': Timestamp.fromDate(createdAt),
        'cashierId': cashierId,
        'cashierName': cashierName,
        'receiptNumber': receiptNumber,
        'status': status,
        'storeId': storeId,
        'loyaltyPointsEarned': loyaltyPointsEarned,
        'loyaltyPointsRedeemed': loyaltyPointsRedeemed,
        'note': note,
        'discountId': discountId,
        'orderDiscount': orderDiscount,
      };

  String get primaryPaymentMethod =>
      payments.isNotEmpty ? payments.first.method : 'cash';

  @override
  List<Object?> get props => [id, status, createdAt];
}

// ─────────────────────────────────────────────
// CUSTOMER
// ─────────────────────────────────────────────
@HiveType(typeId: 6)
class Customer extends HiveObject with EquatableMixin {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String email;
  @HiveField(3) String phone;
  @HiveField(4) double loyaltyPoints;
  @HiveField(5) double totalSpent;
  @HiveField(6) int visitCount;
  @HiveField(7) DateTime createdAt;
  @HiveField(8) DateTime? lastVisit;
  @HiveField(9) String note;
  @HiveField(10) bool isDeleted;
  @HiveField(11) String storeId;
  @HiveField(12) String address;

  Customer({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.loyaltyPoints = 0,
    this.totalSpent = 0,
    this.visitCount = 0,
    required this.createdAt,
    this.lastVisit,
    this.note = '',
    this.isDeleted = false,
    this.storeId = '',
    this.address = '',
  });

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      loyaltyPoints: (d['loyaltyPoints'] as num?)?.toDouble() ?? 0,
      totalSpent: (d['totalSpent'] as num?)?.toDouble() ?? 0,
      visitCount: d['visitCount'] ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastVisit: (d['lastVisit'] as Timestamp?)?.toDate(),
      note: d['note'] ?? '',
      isDeleted: d['isDeleted'] ?? false,
      storeId: d['storeId'] ?? '',
      address: d['address'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'phone': phone,
        'loyaltyPoints': loyaltyPoints,
        'totalSpent': totalSpent,
        'visitCount': visitCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastVisit': lastVisit != null ? Timestamp.fromDate(lastVisit!) : null,
        'note': note,
        'isDeleted': isDeleted,
        'storeId': storeId,
        'address': address,
      };

  Customer copyWith({
    String? name,
    String? email,
    String? phone,
    double? loyaltyPoints,
    double? totalSpent,
    int? visitCount,
    DateTime? lastVisit,
    String? note,
    String? address,
    bool? isDeleted,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
        totalSpent: totalSpent ?? this.totalSpent,
        visitCount: visitCount ?? this.visitCount,
        createdAt: createdAt,
        lastVisit: lastVisit ?? this.lastVisit,
        note: note ?? this.note,
        isDeleted: isDeleted ?? this.isDeleted,
        storeId: storeId,
        address: address ?? this.address,
      );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [id, name, loyaltyPoints, totalSpent];
}

// ─────────────────────────────────────────────
// APP USER (CASHIER / MANAGER)
// ─────────────────────────────────────────────
@HiveType(typeId: 7)
class AppUser extends HiveObject with EquatableMixin {
  @HiveField(0) String uid;
  @HiveField(1) String email;
  @HiveField(2) String displayName;
  @HiveField(3) String role; // 'owner' | 'manager' | 'cashier'
  @HiveField(4) String storeId;
  @HiveField(5) String storeName;
  @HiveField(6) bool isActive;
  @HiveField(7) String photoUrl;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = 'cashier',
    this.storeId = '',
    this.storeName = '',
    this.isActive = true,
    this.photoUrl = '',
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: d['email'] ?? '',
      displayName: d['displayName'] ?? '',
      role: d['role'] ?? 'cashier',
      storeId: d['storeId'] ?? '',
      storeName: d['storeName'] ?? '',
      isActive: d['isActive'] ?? true,
      photoUrl: d['photoUrl'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'role': role,
        'storeId': storeId,
        'storeName': storeName,
        'isActive': isActive,
        'photoUrl': photoUrl,
      };

  bool get isOwner => role == 'owner';
  bool get isManager => role == 'manager' || role == 'owner';

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  @override
  List<Object?> get props => [uid, email, role, storeId];
}
