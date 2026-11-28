/// A ride as the customer's journey screens read it: exactly what the backend's
/// customer ride endpoints send (RideController::serialize with the driver card).
/// Every field is optional and parsed defensively, so a missing value shows as blank
/// instead of crashing the screen.
class CustomerRide {
  final String id;
  final String? refId;
  final String status;
  final String? pickupAddress;
  final String? destinationAddress;
  final double fare;
  final double? distanceKm;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? otp;
  final RideDriverCard? driver;
  final String? cancellationReason;
  final String? cancelledBy;
  final bool reviewSubmitted;
  final String? createdAt;

  const CustomerRide({
    required this.id,
    required this.status,
    this.refId,
    this.pickupAddress,
    this.destinationAddress,
    this.fare = 0,
    this.distanceKm,
    this.paymentStatus,
    this.paymentMethod,
    this.otp,
    this.driver,
    this.cancellationReason,
    this.cancelledBy,
    this.reviewSubmitted = false,
    this.createdAt,
  });

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String ongoing = 'ongoing';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  bool get isActive => status == pending || status == accepted || status == ongoing;
  bool get isPaid => paymentStatus == 'paid';
  bool get canCancel => status == pending || status == accepted;
  bool get needsPayment => status == completed && !isPaid;

  static CustomerRide? tryParse(dynamic json) {
    if (json is! Map) return null;
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return CustomerRide(
      id: id,
      refId: json['ref_id']?.toString(),
      status: json['current_status']?.toString() ?? pending,
      pickupAddress: json['pickup_address']?.toString(),
      destinationAddress: json['destination_address']?.toString(),
      fare: _num(json['total_fare'] ?? json['estimated_fare']) ?? 0,
      distanceKm: _num(json['estimated_distance']),
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      otp: json['otp']?.toString(),
      driver: RideDriverCard.tryParse(json['driver']),
      cancellationReason: json['cancellation_reason']?.toString(),
      cancelledBy: json['cancelled_by']?.toString(),
      reviewSubmitted: json['review_submitted'] == true,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class RideDriverCard {
  final String name;
  final String? phone;
  final String? image;
  final double? rating;
  final int reviews;
  final String? vehicle;
  final String? plate;

  const RideDriverCard({required this.name, this.phone, this.image, this.rating, this.reviews = 0, this.vehicle, this.plate});

  static RideDriverCard? tryParse(dynamic json) {
    if (json is! Map) return null;
    final name = [json['first_name'], json['last_name']].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
    final vehicle = json['vehicle'];
    String? vehicleText;
    String? plate;
    if (vehicle is Map) {
      vehicleText = [vehicle['brand'], vehicle['model']].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      if (vehicleText.isEmpty) vehicleText = vehicle['category']?.toString();
      plate = vehicle['licence_plate_number']?.toString();
    }
    return RideDriverCard(
      name: name.isEmpty ? 'Your driver' : name,
      phone: json['phone']?.toString(),
      image: json['image']?.toString(),
      rating: _num(json['avg_rating']),
      reviews: int.tryParse('${json['total_reviews'] ?? 0}') ?? 0,
      vehicle: vehicleText,
      plate: plate,
    );
  }
}

class RidePaymentOption {
  final String name;
  final String title;
  final double? balance;

  const RidePaymentOption({required this.name, required this.title, this.balance});

  static RidePaymentOption? tryParse(dynamic json) {
    if (json is! Map || json['name'] == null) return null;
    return RidePaymentOption(name: json['name'].toString(), title: json['title']?.toString() ?? json['name'].toString(), balance: _num(json['balance']));
  }
}

double? _num(dynamic value) => value == null ? null : (value is num ? value.toDouble() : double.tryParse(value.toString()));
