// lib/models/models.g.dart
// GENERATED CODE – but manually written here to avoid needing build_runner.
// If you add new Hive fields, regenerate with: flutter pub run build_runner build

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final int typeId = 0;

  @override
  Category read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Category(
      id: fields[0] as String,
      name: fields[1] as String,
      color: fields[2] as String,
      createdAt: fields[3] as DateTime,
      isDeleted: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.color)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.isDeleted);
  }
}

class ProductVariantAdapter extends TypeAdapter<ProductVariant> {
  @override
  final int typeId = 1;

  @override
  ProductVariant read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductVariant(
      id: fields[0] as String,
      name: fields[1] as String,
      price: fields[2] as double,
      cost: fields[3] as double,
      sku: fields[4] as String,
      barcode: fields[5] as String,
      stock: fields[6] as double,
      lowStockAlert: fields[7] as double,
      trackStock: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ProductVariant obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.cost)
      ..writeByte(4)
      ..write(obj.sku)
      ..writeByte(5)
      ..write(obj.barcode)
      ..writeByte(6)
      ..write(obj.stock)
      ..writeByte(7)
      ..write(obj.lowStockAlert)
      ..writeByte(8)
      ..write(obj.trackStock);
  }
}

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 2;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      categoryId: fields[3] as String,
      imageUrl: fields[4] as String,
      variants: (fields[5] as List).cast<ProductVariant>(),
      taxRateId: fields[6] as String,
      isAvailable: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
      isDeleted: fields[10] as bool,
      storeId: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.variants)
      ..writeByte(6)
      ..write(obj.taxRateId)
      ..writeByte(7)
      ..write(obj.isAvailable)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.isDeleted)
      ..writeByte(11)
      ..write(obj.storeId);
  }
}

class CartItemAdapter extends TypeAdapter<CartItem> {
  @override
  final int typeId = 3;

  @override
  CartItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CartItem(
      productId: fields[0] as String,
      productName: fields[1] as String,
      variantId: fields[2] as String,
      variantName: fields[3] as String,
      price: fields[4] as double,
      quantity: fields[5] as double,
      discountId: fields[6] as String?,
      discountAmount: fields[7] as double,
      imageUrl: fields[8] as String,
      taxRateId: fields[9] as String,
      taxRate: fields[10] as double,
    );
  }

  @override
  void write(BinaryWriter writer, CartItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.variantId)
      ..writeByte(3)
      ..write(obj.variantName)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.discountId)
      ..writeByte(7)
      ..write(obj.discountAmount)
      ..writeByte(8)
      ..write(obj.imageUrl)
      ..writeByte(9)
      ..write(obj.taxRateId)
      ..writeByte(10)
      ..write(obj.taxRate);
  }
}

class PaymentLineAdapter extends TypeAdapter<PaymentLine> {
  @override
  final int typeId = 4;

  @override
  PaymentLine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentLine(
      method: fields[0] as String,
      amount: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentLine obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.method)
      ..writeByte(1)
      ..write(obj.amount);
  }
}

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 5;

  @override
  Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Transaction(
      id: fields[0] as String,
      items: (fields[1] as List).cast<CartItem>(),
      payments: (fields[2] as List).cast<PaymentLine>(),
      subtotal: fields[3] as double,
      totalDiscount: fields[4] as double,
      totalTax: fields[5] as double,
      total: fields[6] as double,
      change: fields[7] as double,
      customerId: fields[8] as String?,
      customerName: fields[9] as String?,
      createdAt: fields[10] as DateTime,
      cashierId: fields[11] as String,
      cashierName: fields[12] as String,
      receiptNumber: fields[13] as String,
      status: fields[14] as String,
      isSynced: fields[15] as bool,
      storeId: fields[16] as String,
      loyaltyPointsEarned: fields[17] as double,
      loyaltyPointsRedeemed: fields[18] as double,
      note: fields[19] as String?,
      discountId: fields[20] as String?,
      orderDiscount: fields[21] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.items)
      ..writeByte(2)
      ..write(obj.payments)
      ..writeByte(3)
      ..write(obj.subtotal)
      ..writeByte(4)
      ..write(obj.totalDiscount)
      ..writeByte(5)
      ..write(obj.totalTax)
      ..writeByte(6)
      ..write(obj.total)
      ..writeByte(7)
      ..write(obj.change)
      ..writeByte(8)
      ..write(obj.customerId)
      ..writeByte(9)
      ..write(obj.customerName)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.cashierId)
      ..writeByte(12)
      ..write(obj.cashierName)
      ..writeByte(13)
      ..write(obj.receiptNumber)
      ..writeByte(14)
      ..write(obj.status)
      ..writeByte(15)
      ..write(obj.isSynced)
      ..writeByte(16)
      ..write(obj.storeId)
      ..writeByte(17)
      ..write(obj.loyaltyPointsEarned)
      ..writeByte(18)
      ..write(obj.loyaltyPointsRedeemed)
      ..writeByte(19)
      ..write(obj.note)
      ..writeByte(20)
      ..write(obj.discountId)
      ..writeByte(21)
      ..write(obj.orderDiscount);
  }
}

class CustomerAdapter extends TypeAdapter<Customer> {
  @override
  final int typeId = 6;

  @override
  Customer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Customer(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      phone: fields[3] as String,
      loyaltyPoints: fields[4] as double,
      totalSpent: fields[5] as double,
      visitCount: fields[6] as int,
      createdAt: fields[7] as DateTime,
      lastVisit: fields[8] as DateTime?,
      note: fields[9] as String,
      isDeleted: fields[10] as bool,
      storeId: fields[11] as String,
      address: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Customer obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.loyaltyPoints)
      ..writeByte(5)
      ..write(obj.totalSpent)
      ..writeByte(6)
      ..write(obj.visitCount)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.lastVisit)
      ..writeByte(9)
      ..write(obj.note)
      ..writeByte(10)
      ..write(obj.isDeleted)
      ..writeByte(11)
      ..write(obj.storeId)
      ..writeByte(12)
      ..write(obj.address);
  }
}

class AppUserAdapter extends TypeAdapter<AppUser> {
  @override
  final int typeId = 7;

  @override
  AppUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUser(
      uid: fields[0] as String,
      email: fields[1] as String,
      displayName: fields[2] as String,
      role: fields[3] as String,
      storeId: fields[4] as String,
      storeName: fields[5] as String,
      isActive: fields[6] as bool,
      photoUrl: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppUser obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.role)
      ..writeByte(4)
      ..write(obj.storeId)
      ..writeByte(5)
      ..write(obj.storeName)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.photoUrl);
  }
}

class TaxRateAdapter extends TypeAdapter<TaxRate> {
  @override
  final int typeId = 8;

  @override
  TaxRate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxRate(
      id: fields[0] as String,
      name: fields[1] as String,
      rate: fields[2] as double,
      inclusive: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TaxRate obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.rate)
      ..writeByte(3)
      ..write(obj.inclusive);
  }
}

class DiscountAdapter extends TypeAdapter<Discount> {
  @override
  final int typeId = 9;

  @override
  Discount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Discount(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      value: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Discount obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.value);
  }
}
