import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product_item.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  String? _vendorId;
  String? _vendorName;
  final List<CartItem> _items = [];

  String? get vendorId => _vendorId;
  String? get vendorName => _vendorName;
  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get totalItemCount {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  double getTotalItemsPrice() {
    return _items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  int getItemQuantity(String productId, {String? sizeId}) {
    final item = _items.firstWhere(
      (item) => item.productId == productId && item.sizeId == sizeId,
      orElse: () => CartItem(productId: '', name: '', price: 0, quantity: 0),
    );
    return item.quantity;
  }

  bool needsVendorSwitch(String newVendorId) {
    if (_vendorId == null || _items.isEmpty) {
      return false;
    }
    return _vendorId != newVendorId;
  }

  String getCartDescription() {
    if (_items.isEmpty) {
      return '';
    }

    final descriptions = _items.map((item) => item.toDescriptionString()).toList();
    final itemsDescription = descriptions.join('\n');
    final total = getTotalItemsPrice();

    return '$itemsDescription\n-----\nالإجمالي: ${total.toStringAsFixed(0)} ج.م';
  }

  /// [size], when given, picks which ItemSizeOption this line represents —
  /// its (discount) price is used instead of the product's base price, and
  /// it's tracked as its own cart line separate from other sizes of the
  /// same product.
  void addItem(ProductItem product, String vendorId, String vendorName, {ItemSizeOption? size}) {
    // Set vendor if cart is empty
    if (_items.isEmpty) {
      _vendorId = vendorId;
      _vendorName = vendorName;
    }

    // Check if item already exists
    final existingIndex = _items.indexWhere(
      (item) => item.productId == product.id && item.sizeId == size?.id,
    );

    if (existingIndex >= 0) {
      // Increment quantity
      _items[existingIndex].quantity++;
    } else {
      // Add new item
      _items.add(CartItem(
        productId: product.id,
        name: product.name,
        price: size?.effectivePrice ?? product.price,
        quantity: 1,
        sizeId: size?.id,
        sizeName: size?.name,
      ));
    }

    notifyListeners();
  }

  void removeItem(String productId, {String? sizeId}) {
    final existingIndex = _items.indexWhere(
      (item) => item.productId == productId && item.sizeId == sizeId,
    );

    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        // Decrement quantity
        _items[existingIndex].quantity--;
      } else {
        // Remove item completely
        _items.removeAt(existingIndex);
      }

      // Clear vendor if cart is empty
      if (_items.isEmpty) {
        _vendorId = null;
        _vendorName = null;
      }

      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _vendorId = null;
    _vendorName = null;
    notifyListeners();
  }

  void updateItemQuantity(String productId, int newQuantity, {String? sizeId}) {
    if (newQuantity <= 0) {
      // Remove item if quantity is 0 or less
      _items.removeWhere((item) => item.productId == productId && item.sizeId == sizeId);

      // Clear vendor if cart is empty
      if (_items.isEmpty) {
        _vendorId = null;
        _vendorName = null;
      }
    } else {
      final existingIndex = _items.indexWhere(
        (item) => item.productId == productId && item.sizeId == sizeId,
      );

      if (existingIndex >= 0) {
        _items[existingIndex].quantity = newQuantity;
      }
    }

    notifyListeners();
  }
}
