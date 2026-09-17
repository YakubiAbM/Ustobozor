class ServiceCategory {
  ServiceCategory({required this.id, required this.name});
  final int id;
  final String name;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
        id: int.tryParse('${json['id']}') ?? 0,
        name: '${json['name'] ?? ''}',
      );

  @override
  bool operator ==(Object other) =>
      other is ServiceCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class CatalogService {
  CatalogService({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.title,
    required this.priceClient,
    required this.commissionFee,
    required this.isActive,
  });

  final int id;
  final int categoryId;
  final String categoryName;
  final String title;
  final double priceClient;
  final double commissionFee;
  final bool isActive;

  factory CatalogService.fromJson(Map<String, dynamic> json) => CatalogService(
        id: int.tryParse('${json['id']}') ?? 0,
        categoryId: int.tryParse('${json['category_id']}') ?? 0,
        categoryName: '${json['category_name'] ?? ''}',
        title: '${json['title'] ?? ''}',
        priceClient: double.tryParse('${json['price_client']}') ?? 0,
        commissionFee: double.tryParse('${json['commission_fee']}') ?? 0,
        isActive: json['is_active'] == true || json['is_active'] == 1,
      );
}

class OrderMasterInfo {
  OrderMasterInfo({
    required this.id,
    required this.name,
    required this.image,
    required this.rating,
    required this.reviewsCount,
    this.phone = '',
    this.specialization = '',
    this.city = '',
    this.description = '',
    this.experience = 0,
  });

  final int id;
  final String name;
  final String image;
  final double rating;
  final int reviewsCount;
  final String phone;
  final String specialization;
  final String city;
  final String description;
  final int experience;

  String get ratingLabel {
    final r = rating.toStringAsFixed(rating == rating.roundToDouble() ? 0 : 1);
    return '★$r · $reviewsCount отзыв${_pluralReviews(reviewsCount)}';
  }

  static String _pluralReviews(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return '';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) return 'а';
    return 'ов';
  }

  factory OrderMasterInfo.fromJson(Map<String, dynamic> json) => OrderMasterInfo(
        id: int.tryParse('${json['id']}') ?? 0,
        name: '${json['name'] ?? 'Мастер'}',
        image: '${json['image'] ?? ''}',
        rating: double.tryParse('${json['rating']}') ?? 0,
        reviewsCount: int.tryParse('${json['reviews_count']}') ?? 0,
        phone: '${json['phone'] ?? ''}',
        specialization: '${json['specialization'] ?? ''}',
        city: '${json['city'] ?? ''}',
        description: '${json['description'] ?? ''}',
        experience: int.tryParse('${json['experience']}') ?? 0,
      );
}

class ServiceOrder {
  ServiceOrder({
    required this.id,
    required this.serviceId,
    required this.serviceTitle,
    required this.categoryName,
    required this.address,
    required this.comment,
    required this.status,
    required this.priceClient,
    required this.commissionFee,
    required this.createdAt,
    this.scheduledDate = '',
    this.scheduledTime = '',
    this.latitude,
    this.longitude,
    this.hasLocation = false,
    this.hasReview = false,
    this.masterId,
    this.master,
    this.clientName = '',
    this.clientPhone = '',
    this.photos = const [],
  });

  final int id;
  final int serviceId;
  final String serviceTitle;
  final String categoryName;
  final String address;
  final String comment;
  final String status;
  final double priceClient;
  final double commissionFee;
  final String createdAt;
  final String scheduledDate;
  final String scheduledTime;
  final double? latitude;
  final double? longitude;
  final bool hasLocation;
  final bool hasReview;
  final int? masterId;
  final OrderMasterInfo? master;
  final String clientName;
  final String clientPhone;
  final List<String> photos;

  bool get isNew => status.toUpperCase() == 'NEW';
  bool get isInProgress => status.toUpperCase() == 'IN_PROGRESS';
  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  bool get hasContacts => clientPhone.trim().isNotEmpty;

  bool get hasPreciseLocation => latitude != null && longitude != null;

  bool get hasAssignedMaster =>
      master != null || (masterId != null && masterId! > 0);

  String get scheduleLabel {
    final d = scheduledDate.trim();
    final t = scheduledTime.trim();
    if (d.isEmpty && t.isEmpty) return '';
    if (d.isEmpty) return t;
    if (t.isEmpty) return d;
    return '$d · $t';
  }

  String get statusLabelRu {
    switch (status.toUpperCase()) {
      case 'NEW':
        return 'Ищем мастера';
      case 'IN_PROGRESS':
        return 'В работе';
      case 'COMPLETED':
        return 'Завершён';
      case 'CANCELLED':
        return 'Отменён';
      default:
        return status;
    }
  }

  factory ServiceOrder.fromJson(Map<String, dynamic> json) {
    final photosRaw = json['photos'];
    final photos = <String>[];
    if (photosRaw is List) {
      for (final p in photosRaw) {
        final s = '$p'.trim();
        if (s.isNotEmpty) photos.add(s);
      }
    }
    double? parseCoord(dynamic v) {
      if (v == null) return null;
      return double.tryParse('$v');
    }

    final lat = parseCoord(json['latitude']);
    final lng = parseCoord(json['longitude']);
    final addressText =
        '${json['address_text'] ?? json['address'] ?? ''}'.trim();

    OrderMasterInfo? master;
    final masterRaw = json['master'];
    if (masterRaw is Map) {
      master = OrderMasterInfo.fromJson(Map<String, dynamic>.from(masterRaw));
    }

    return ServiceOrder(
      id: int.tryParse('${json['id']}') ?? 0,
      serviceId: int.tryParse('${json['service_id']}') ?? 0,
      serviceTitle: '${json['service_title'] ?? ''}',
      categoryName: '${json['category_name'] ?? ''}',
      address: addressText,
      comment: '${json['comment'] ?? ''}',
      status: '${json['status'] ?? ''}',
      priceClient: double.tryParse('${json['price_client']}') ?? 0,
      commissionFee: double.tryParse('${json['commission_fee']}') ?? 0,
      createdAt: '${json['created_at'] ?? ''}',
      scheduledDate: '${json['scheduled_date'] ?? ''}',
      scheduledTime: '${json['scheduled_time'] ?? ''}',
      latitude: lat,
      longitude: lng,
      hasLocation: json['has_location'] == true || (lat != null && lng != null),
      hasReview: json['has_review'] == true,
      masterId: json['master_id'] == null
          ? null
          : int.tryParse('${json['master_id']}'),
      master: master,
      clientName: '${json['client_name'] ?? ''}',
      clientPhone: '${json['client_phone'] ?? ''}',
      photos: photos,
    );
  }
}

class MasterReview {
  MasterReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.clientName,
    this.photos = const [],
  });

  final int id;
  final int rating;
  final String comment;
  final String createdAt;
  final String clientName;
  final List<String> photos;

  factory MasterReview.fromJson(Map<String, dynamic> json) {
    final photos = <String>[];
    final raw = json['photos'];
    if (raw is List) {
      for (final p in raw) {
        final s = '$p'.trim();
        if (s.isNotEmpty) photos.add(s);
      }
    }
    return MasterReview(
      id: int.tryParse('${json['id']}') ?? 0,
      rating: int.tryParse('${json['rating']}') ?? 0,
      comment: '${json['comment'] ?? ''}',
      createdAt: '${json['created_at'] ?? ''}',
      clientName: '${json['client_name'] ?? 'Клиент'}',
      photos: photos,
    );
  }
}

class BalanceTx {
  BalanceTx({
    required this.id,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.orderId,
    this.note = '',
  });

  final int id;
  final double amount;
  final String type;
  final String createdAt;
  final int? orderId;
  final String note;

  factory BalanceTx.fromJson(Map<String, dynamic> json) => BalanceTx(
        id: int.tryParse('${json['id']}') ?? 0,
        amount: double.tryParse('${json['amount']}') ?? 0,
        type: '${json['type'] ?? ''}',
        createdAt: '${json['created_at'] ?? ''}',
        orderId: json['order_id'] == null
            ? null
            : int.tryParse('${json['order_id']}'),
        note: '${json['note'] ?? ''}',
      );
}
