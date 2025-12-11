import 'package:cloud_firestore/cloud_firestore.dart';

enum MenuCategory { drink, food, beer }

extension MenuCategoryX on MenuCategory {
  String get label {
    switch (this) {
      case MenuCategory.drink:
        return 'ドリンク';
      case MenuCategory.food:
        return 'フード';
      case MenuCategory.beer:
        return 'ビール';
    }
  }

  String get firestoreValue {
    switch (this) {
      case MenuCategory.drink:
        return 'drink';
      case MenuCategory.food:
        return 'food';
      case MenuCategory.beer:
        return 'beer';
    }
  }

  static MenuCategory fromFirestoreValue(String? value) {
    switch (value) {
      case 'drink':
        return MenuCategory.drink;
      case 'beer':
        return MenuCategory.beer;
      case 'food':
      default:
        return MenuCategory.food;
    }
  }
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int price;
  final MenuCategory category;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MenuItem.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final timestamp = data?['createdAt'];
    final updatedTimestamp = data?['updatedAt'];
    return MenuItem(
      id: doc.id,
      name: (data?['name'] as String?) ?? '',
      price: (data?['price'] as num?)?.toInt() ?? 0,
      category: MenuCategoryX.fromFirestoreValue(
        data?['category'] as String?,
      ),
      imageUrl: data?['imageUrl'] as String?,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      updatedAt:
          updatedTimestamp is Timestamp ? updatedTimestamp.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'category': category.firestoreValue,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
