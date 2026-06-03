class ZoneResponseModel {
  final bool _isSuccess;
  final List<int> _zoneIds;
  final String? _message;
  final List<ZoneData> _zoneData;
  final List<int> _areaIds;
  final int? statusCode;
  final String? _zoneId;
  ZoneResponseModel(this._isSuccess, this._message, this._zoneIds, this._zoneData, this._areaIds, this.statusCode, this._zoneId);

  String? get message => _message;
  List<int> get zoneIds => _zoneIds;
  bool get isSuccess => _isSuccess;
  List<ZoneData> get zoneData => _zoneData;
  List<int> get areaIds => _areaIds;
  int? get status => statusCode;
  String? get zoneId => _zoneId;
}

class ZoneData {
  int? id;
  int? status;
  bool? cashOnDelivery;
  bool? digitalPayment;
  bool? offlinePayment;
  double? increaseDeliveryFee;
  int? increaseDeliveryFeeStatus;
  String? increaseDeliveryFeeMessage;
  String? currencyCode;
  List<String>? paymentGateways;
  List<MicroZoneData>? microZones;
  List<Modules>? modules;

  ZoneData({
    this.id,
    this.status,
    this.cashOnDelivery,
    this.digitalPayment,
    this.offlinePayment,
    this.increaseDeliveryFee,
    this.increaseDeliveryFeeStatus,
    this.increaseDeliveryFeeMessage,
    this.currencyCode,
    this.paymentGateways,
    this.microZones,
    this.modules,
  });

  ZoneData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    status = json['status'];
    cashOnDelivery = json['cash_on_delivery'];
    digitalPayment = json['digital_payment'];
    offlinePayment = json['offline_payment'];
    increaseDeliveryFee = json['increased_delivery_fee']?.toDouble();
    increaseDeliveryFeeStatus = json['increased_delivery_fee_status'];
    increaseDeliveryFeeMessage = json['increase_delivery_charge_message'];
    currencyCode = json['currency_code']?.toString();
    if (json['payment_gateways'] != null) {
      paymentGateways = <String>[];
      json['payment_gateways'].forEach((v) {
        paymentGateways!.add(v is Map ? (v['gateway_key'] ?? '').toString() : v.toString());
      });
    }
    if (json['micro_zones'] != null) {
      microZones = <MicroZoneData>[];
      json['micro_zones'].forEach((v) {
        microZones!.add(MicroZoneData.fromJson(v));
      });
    }
    if (json['modules'] != null) {
      modules = <Modules>[];
      json['modules'].forEach((v) {
        modules!.add(Modules.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['status'] = status;
    data['cash_on_delivery'] = cashOnDelivery;
    data['digital_payment'] = digitalPayment;
    data['offline_payment'] = offlinePayment;
    data['currency_code'] = currencyCode;
    data['payment_gateways'] = paymentGateways;
    if (microZones != null) {
      data['micro_zones'] = microZones!.map((v) => v.toJson()).toList();
    }
    if (modules != null) {
      data['modules'] = modules!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class MicroZoneData {
  int? id;
  int? zoneId;
  String? name;

  MicroZoneData({this.id, this.zoneId, this.name});

  MicroZoneData.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id'].toString());
    zoneId = int.tryParse(json['zone_id'].toString());
    name = json['name']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['zone_id'] = zoneId;
    data['name'] = name;
    return data;
  }
}

class Modules {
  int? id;
  String? moduleName;
  String? moduleType;
  String? thumbnail;
  String? status;
  int? storesCount;
  String? createdAt;
  String? updatedAt;
  String? icon;
  int? themeId;
  String? description;
  int? allZoneService;
  Pivot? pivot;

  Modules({
    this.id,
    this.moduleName,
    this.moduleType,
    this.thumbnail,
    this.status,
    this.storesCount,
    this.createdAt,
    this.updatedAt,
    this.icon,
    this.themeId,
    this.description,
    this.allZoneService,
    this.pivot,
  });

  Modules.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    moduleName = json['module_name'];
    moduleType = json['module_type'];
    thumbnail = json['thumbnail'];
    status = json['status'];
    storesCount = json['stores_count'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    icon = json['icon'];
    themeId = json['theme_id'];
    description = json['description'];
    allZoneService = json['all_zone_service'];
    pivot = json['pivot'] != null ? Pivot.fromJson(json['pivot']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['module_name'] = moduleName;
    data['module_type'] = moduleType;
    data['thumbnail'] = thumbnail;
    data['status'] = status;
    data['stores_count'] = storesCount;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['icon'] = icon;
    data['theme_id'] = themeId;
    data['description'] = description;
    data['all_zone_service'] = allZoneService;
    if (pivot != null) {
      data['pivot'] = pivot!.toJson();
    }
    return data;
  }
}

class Pivot {
  int? zoneId;
  int? moduleId;
  double? perKmShippingCharge;
  double? minimumShippingCharge;
  double? maximumShippingCharge;
  double? maximumCodOrderAmount;
  String? deliveryChargeType;
  double? fixedShippingCharge;

  Pivot({
    this.zoneId,
    this.moduleId,
    this.perKmShippingCharge,
    this.minimumShippingCharge,
    this.maximumShippingCharge,
    this.maximumCodOrderAmount,
    this.deliveryChargeType,
    this.fixedShippingCharge,
  });

  Pivot.fromJson(Map<String, dynamic> json) {
    zoneId = json['zone_id'];
    moduleId = json['module_id'];
    perKmShippingCharge = json['per_km_shipping_charge']?.toDouble();
    minimumShippingCharge = json['minimum_shipping_charge']?.toDouble();
    maximumShippingCharge =  json['maximum_shipping_charge']?.toDouble();
    maximumCodOrderAmount = json['maximum_cod_order_amount']?.toDouble();
    deliveryChargeType = json['delivery_charge_type'];
    fixedShippingCharge = double.tryParse(json['fixed_shipping_charge'].toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['zone_id'] = zoneId;
    data['module_id'] = moduleId;
    data['per_km_shipping_charge'] = perKmShippingCharge;
    data['minimum_shipping_charge'] = minimumShippingCharge;
    data['maximum_shipping_charge'] = maximumShippingCharge;
    data['maximum_cod_order_amount'] = maximumCodOrderAmount;
    data['delivery_charge_type'] = deliveryChargeType;
    data['fixed_shipping_charge'] = fixedShippingCharge;
    return data;
  }
}
