class CartItem {
  final String productId;
  final String name;
  final double price;
  int quantity;
  // Which size variant this line represents — null for a product with no
  // sizes. Two different sizes of the same product are two separate
  // CartItems (see CartService's dedup key), since they can have
  // different prices.
  final String? sizeId;
  final String? sizeName;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.sizeId,
    this.sizeName,
  });

  double get subtotal => price * quantity;

  String toDescriptionString() {
    final label = sizeName != null && sizeName!.isNotEmpty ? '$name ($sizeName)' : name;
    return '$label x$quantity (${subtotal.toStringAsFixed(0)} جنيه)';
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      if (sizeId != null) 'sizeId': sizeId,
      if (sizeName != null) 'sizeName': sizeName,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      quantity: json['quantity'] is int
          ? json['quantity']
          : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      sizeId: json['sizeId']?.toString(),
      sizeName: json['sizeName']?.toString(),
    );
  }

  @override
  String toString() {
    return 'CartItem{productId: $productId, sizeId: $sizeId, name: $name, price: $price, quantity: $quantity}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          sizeId == other.sizeId;

  @override
  int get hashCode => Object.hash(productId, sizeId);
}
