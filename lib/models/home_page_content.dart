import 'package:cloud_firestore/cloud_firestore.dart';

enum HomePageGenre { sales, event, news }

enum HomePageButtonType { reserve, order }

extension HomePageButtonTypeX on HomePageButtonType {
  String get label {
    switch (this) {
      case HomePageButtonType.reserve:
        return '予約する';
      case HomePageButtonType.order:
        return '注文する';
    }
  }

  String get firestoreValue {
    switch (this) {
      case HomePageButtonType.reserve:
        return 'reserve';
      case HomePageButtonType.order:
        return 'order';
    }
  }

  static HomePageButtonType fromFirestoreValue(String? value) {
    switch (value) {
      case 'order':
        return HomePageButtonType.order;
      case 'reserve':
      default:
        return HomePageButtonType.reserve;
    }
  }
}

extension HomePageGenreX on HomePageGenre {
  String get label {
    switch (this) {
      case HomePageGenre.sales:
        return '販売';
      case HomePageGenre.event:
        return 'イベント';
      case HomePageGenre.news:
        return 'ニュース';
    }
  }

  String get firestoreValue {
    switch (this) {
      case HomePageGenre.sales:
        return 'sales';
      case HomePageGenre.event:
        return 'event';
      case HomePageGenre.news:
        return 'news';
    }
  }

  static HomePageGenre fromFirestoreValue(String? value) {
    switch (value) {
      case 'sales':
        return HomePageGenre.sales;
      case 'event':
        return HomePageGenre.event;
      case 'news':
      default:
        return HomePageGenre.news;
    }
  }
}

class HomePageContent {
  const HomePageContent({
    required this.id,
    required this.title,
    required this.body,
    required this.genre,
    required this.imageUrls,
    required this.displayOrder,
    required this.buttonType,
    this.price,
    this.eventDate,
    this.startTimeLabel,
    this.endTimeLabel,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final HomePageGenre genre;
  final List<String> imageUrls;
  final int displayOrder;
  final HomePageButtonType buttonType;
  final int? price;
  final DateTime? eventDate;
  final String? startTimeLabel;
  final String? endTimeLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory HomePageContent.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final timestamp = data?['createdAt'];
    final updatedTimestamp = data?['updatedAt'];
    final List<dynamic>? rawImageUrls = data?['imageUrls'] as List<dynamic>?;
    return HomePageContent(
      id: doc.id,
      title: (data?['title'] as String?) ?? '',
      body: (data?['body'] as String?) ?? '',
      genre: HomePageGenreX.fromFirestoreValue(
        data?['genre'] as String?,
      ),
      imageUrls: rawImageUrls == null
          ? const []
          : rawImageUrls
              .whereType<String>()
              .toList(growable: false),
      displayOrder: (data?['displayOrder'] as num?)?.toInt() ?? 0,
      buttonType:
          HomePageButtonTypeX.fromFirestoreValue(data?['buttonType'] as String?),
      price: (data?['price'] as num?)?.toInt(),
      eventDate: (data?['eventDate'] as Timestamp?)?.toDate(),
      startTimeLabel: data?['startTime'] as String?,
      endTimeLabel: data?['endTime'] as String?,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      updatedAt:
          updatedTimestamp is Timestamp ? updatedTimestamp.toDate() : null,
    );
  }
}
