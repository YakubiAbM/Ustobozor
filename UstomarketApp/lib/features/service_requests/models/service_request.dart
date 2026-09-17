class ServiceRequestResponse {
  const ServiceRequestResponse({
    required this.id,
    required this.masterId,
    required this.masterName,
    required this.masterPhone,
    this.proposedPrice,
    this.comment = '',
    this.createdAt = '',
  });

  final int id;
  final int masterId;
  final String masterName;
  final String masterPhone;
  final double? proposedPrice;
  final String comment;
  final String createdAt;

  factory ServiceRequestResponse.fromJson(Map<String, dynamic> json) {
    return ServiceRequestResponse(
      id: int.tryParse('${json['id']}') ?? 0,
      masterId: int.tryParse('${json['master_id']}') ?? 0,
      masterName: '${json['master_name'] ?? ''}',
      masterPhone: '${json['master_phone'] ?? ''}',
      proposedPrice: json['proposed_price'] == null
          ? null
          : double.tryParse('${json['proposed_price']}'),
      comment: '${json['comment'] ?? ''}',
      createdAt: '${json['created_at'] ?? ''}',
    );
  }
}

class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.title,
    required this.category,
    this.description = '',
    this.address = '',
    this.city = '',
    this.budget,
    this.status = 'open',
    this.createdAt = '',
    this.clientName = '',
    this.clientPhone = '',
    this.photos = const [],
    this.responses = const [],
    this.responsesCount = 0,
    this.myResponse,
  });

  final int id;
  final String title;
  final String category;
  final String description;
  final String address;
  final String city;
  final double? budget;
  final String status;
  final String createdAt;
  final String clientName;
  final String clientPhone;
  final List<String> photos;
  final List<ServiceRequestResponse> responses;
  final int responsesCount;
  final ServiceRequestResponse? myResponse;

  bool get isOpen => status == 'open';

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    final photos = ((json['photos'] as List?) ?? const [])
        .map((e) => '$e')
        .where((e) => e.isNotEmpty)
        .toList();
    final responses = ((json['responses'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ServiceRequestResponse.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    ServiceRequestResponse? mine;
    final my = json['my_response'];
    if (my is Map) {
      mine = ServiceRequestResponse.fromJson(Map<String, dynamic>.from(my));
    }
    return ServiceRequest(
      id: int.tryParse('${json['id']}') ?? 0,
      title: '${json['title'] ?? ''}',
      category: '${json['category'] ?? ''}',
      description: '${json['description'] ?? ''}',
      address: '${json['address'] ?? ''}',
      city: '${json['city'] ?? ''}',
      budget: json['budget'] == null ? null : double.tryParse('${json['budget']}'),
      status: '${json['status'] ?? 'open'}',
      createdAt: '${json['created_at'] ?? ''}',
      clientName: '${json['client_name'] ?? ''}',
      clientPhone: '${json['client_phone'] ?? ''}',
      photos: photos,
      responses: responses,
      responsesCount: int.tryParse('${json['responses_count']}') ?? responses.length,
      myResponse: mine,
    );
  }
}
