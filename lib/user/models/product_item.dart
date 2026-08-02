class ItemSizeOption {
  final String? id;
  final String name;
  final double price;
  final double? discountPrice;
  final bool isAvailable;

  ItemSizeOption({
    this.id,
    required this.name,
    required this.price,
    this.discountPrice,
    this.isAvailable = true,
  });

  /// The price to actually charge for this size — the discount price when
  /// the vendor set one, otherwise the regular size price.
  double get effectivePrice => discountPrice ?? price;

  factory ItemSizeOption.fromJson(Map<String, dynamic> json) {
    return ItemSizeOption(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      discountPrice: json['discountPrice'] == null
          ? null
          : (json['discountPrice'] is num
              ? (json['discountPrice'] as num).toDouble()
              : double.tryParse(json['discountPrice'].toString())),
      isAvailable: json['isAvailable'] == true ||
          json['isAvailable']?.toString().toLowerCase() == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'price': price,
      if (discountPrice != null) 'discountPrice': discountPrice,
      'isAvailable': isAvailable,
    };
  }
}

class ProductItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageLink;
  final bool isAvailable;
  final String vendorId;
  final String? imageUrl;
  final List<ItemSizeOption> sizes;

  ProductItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageLink,
    required this.isAvailable,
    required this.vendorId,
    this.imageUrl,
    this.sizes = const [],
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      imageLink: json['imageLink']?.toString() ?? '',
      isAvailable: json['isAvailable'] == true ||
          json['isAvailable']?.toString().toLowerCase() == 'true',
      vendorId: json['vendorId']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      sizes: json['sizes'] is List
          ? (json['sizes'] as List)
              .map((s) => ItemSizeOption.fromJson(s as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageLink': imageLink,
      'isAvailable': isAvailable,
      'vendorId': vendorId,
      'imageUrl': imageUrl,
      'sizes': sizes.map((s) => s.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'ProductItem{id: $id, name: $name, price: $price, isAvailable: $isAvailable}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
