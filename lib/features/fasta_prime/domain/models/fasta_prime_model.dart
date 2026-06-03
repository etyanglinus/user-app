class FastaPrimePlan {
  int? id;
  String? name;
  String? description;
  double? price;
  int? validityDays;
  int? freeDeliveryLimit;
  double? maxDeliveryDiscount;

  FastaPrimePlan({
    this.id,
    this.name,
    this.description,
    this.price,
    this.validityDays,
    this.freeDeliveryLimit,
    this.maxDeliveryDiscount,
  });

  FastaPrimePlan.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id'].toString());
    name = json['name']?.toString();
    description = json['description']?.toString();
    price = double.tryParse(json['price'].toString()) ?? 0;
    validityDays = int.tryParse(json['validity_days'].toString()) ?? 30;
    freeDeliveryLimit = int.tryParse(json['free_delivery_limit'].toString()) ?? 0;
    maxDeliveryDiscount = double.tryParse(json['max_delivery_discount'].toString()) ?? 0;
  }
}

class FastaPrimeSubscription {
  int? id;
  String? paymentStatus;
  String? startDate;
  String? endDate;
  bool isCanceled = false;
  FastaPrimePlan? plan;

  FastaPrimeSubscription({this.id, this.paymentStatus, this.startDate, this.endDate, this.plan});

  FastaPrimeSubscription.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id'].toString());
    paymentStatus = json['payment_status']?.toString();
    startDate = json['start_date']?.toString();
    endDate = json['end_date']?.toString();
    isCanceled = json['is_canceled'].toString() == '1' || json['is_canceled'] == true;
    plan = json['plan'] != null ? FastaPrimePlan.fromJson(json['plan']) : null;
  }
}
