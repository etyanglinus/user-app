class DeliveryManBody {
  String? fName;
  String? lName;
  String? phone;
  String? email;
  String? password;
  String? identityType;
  String? identityNumber;
  String? earning;
  String? zoneId;
  String? microZoneId;
  String? vehicleId;
  String? maxWeight;
  String? referCode;
  String? type;

  DeliveryManBody({
    this.fName,
    this.lName,
    this.phone,
    this.email,
    this.password,
    this.identityType,
    this.identityNumber,
    this.earning,
    this.zoneId,
    this.microZoneId,
    this.vehicleId,
    this.maxWeight,
    this.referCode,
    this.type
  });

  DeliveryManBody.fromJson(Map<String, dynamic> json) {
    fName = json['f_name'];
    lName = json['l_name'];
    phone = json['phone'];
    email = json['email'];
    password = json['password'];
    identityType = json['identity_type'];
    identityNumber = json['identity_number'];
    earning = json['earning'];
    zoneId = json['zone_id'];
    microZoneId = json['micro_zone_id'];
    vehicleId = json['vehicle_id'];
    maxWeight = json['max_weight'];
    referCode = json['referral_code'];
    type = json['type'];
  }

  Map<String, String> toJson() {
    final Map<String, String> data = <String, String>{};
    data['f_name'] = fName!;
    data['l_name'] = lName!;
    data['phone'] = phone!;
    data['email'] = email!;
    data['password'] = password!;
    data['identity_type'] = identityType!;
    data['identity_number'] = identityNumber!;
    if(earning != null && earning!.isNotEmpty){
      data['earning'] = earning!;
    }
    data['zone_id'] = zoneId!;
    if(microZoneId != null && microZoneId!.isNotEmpty){
      data['micro_zone_id'] = microZoneId!;
    }
    if(vehicleId !=null && vehicleId!.isNotEmpty){
      data['vehicle_id'] = vehicleId!;
    }
    if(maxWeight != null && maxWeight!.isNotEmpty){
      data['max_weight'] = maxWeight!;
    }
    if(referCode != null && referCode!.isNotEmpty) {
      data['referral_code'] = referCode!;
    }
    data['type'] = type!;
    return data;
  }
}
