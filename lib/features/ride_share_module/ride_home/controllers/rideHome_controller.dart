import 'package:fasta_deliveries/api/api_client.dart';
import 'package:fasta_deliveries/api/response_parser.dart';
import 'package:fasta_deliveries/features/address/domain/models/address_model.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/domain/models/estimated_fare_model.dart';
import 'package:get/get.dart';

import '../domain/services/rideHome_service_interface.dart';

class RideHomeController extends GetxController implements GetxService {
  final RideHomeServiceInterface rideHomeServiceInterface;

  RideHomeController({required this.rideHomeServiceInterface});

  AddressModel? _pickup;
  AddressModel? get pickup => _pickup;

  AddressModel? _destination;
  AddressModel? get destination => _destination;

  List<FareModel> _fareOptions = <FareModel>[];
  List<FareModel> get fareOptions => _fareOptions;

  bool _hasEstimatedFare = false;
  bool get hasEstimatedFare => _hasEstimatedFare;

  bool _isLoadingFare = false;
  bool get isLoadingFare => _isLoadingFare;

  bool _isRequestingRide = false;
  bool get isRequestingRide => _isRequestingRide;

  bool _rideSubmitted = false;
  bool get rideSubmitted => _rideSubmitted;

  String? _requestReference;
  String? get requestReference => _requestReference;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void setPickup(AddressModel address) {
    _pickup = address;
    _clearQuote();
  }

  void setDestination(AddressModel address) {
    _destination = address;
    _clearQuote();
  }

  Future<void> loadData() async {
    if (_pickup != null && _destination != null && !_rideSubmitted) {
      await estimateFare();
    }
  }

  Future<void> estimateFare() async {
    final Map<String, double>? pickupCoordinates = _coordinates(_pickup);
    final Map<String, double>? destinationCoordinates = _coordinates(_destination);
    if (pickupCoordinates == null || destinationCoordinates == null) {
      _errorMessage = 'Choose valid pickup and destination locations.';
      update();
      return;
    }
    if (_isLoadingFare || _isRequestingRide) return;

    _isLoadingFare = true;
    _errorMessage = null;
    _fareOptions = <FareModel>[];
    _hasEstimatedFare = false;
    _rideSubmitted = false;
    _requestReference = null;
    update();

    final response = await rideHomeServiceInterface.estimateFare(
      <String, dynamic>{
        'pickup_coordinates': pickupCoordinates,
        'destination_coordinates': destinationCoordinates,
      },
    );

    if (ApiClient.isSuccessCode(response.statusCode)) {
      final dynamic payload = ResponseParser.payloadOf(response.body);
      final List<dynamic>? rows = ResponseParser.listOf(payload);
      if (rows == null) {
        _errorMessage = 'The fare estimate returned an invalid response.';
      } else {
        final List<FareModel> options = <FareModel>[];
        for (final dynamic row in rows) {
          if (row is! Map) {
            _errorMessage = 'The fare estimate returned an invalid option.';
            break;
          }
          options.add(FareModel.fromJson(Map<String, dynamic>.from(row)));
        }
        if (_errorMessage == null) {
          _fareOptions = options;
          _hasEstimatedFare = true;
        }
      }
    } else {
      _errorMessage =
          response.statusText ?? 'Unable to estimate fares for this route.';
    }

    _isLoadingFare = false;
    update();
  }

  Future<bool> requestRide(FareModel fare) async {
    final Map<String, double>? pickupCoordinates = _coordinates(_pickup);
    final Map<String, double>? destinationCoordinates = _coordinates(_destination);
    final String? vehicleCategoryId = fare.vehicleCategoryId;
    final String? pickupAddress = _pickup?.address?.trim();
    final String? destinationAddress = _destination?.address?.trim();
    if (pickupCoordinates == null ||
        destinationCoordinates == null ||
        vehicleCategoryId == null ||
        vehicleCategoryId.isEmpty ||
        pickupAddress == null ||
        pickupAddress.isEmpty ||
        destinationAddress == null ||
        destinationAddress.isEmpty) {
      _errorMessage = 'Choose a ride option and valid locations first.';
      update();
      return false;
    }
    if (_isRequestingRide || _isLoadingFare) return false;

    _isRequestingRide = true;
    _errorMessage = null;
    update();

    final response = await rideHomeServiceInterface.createRide(
      <String, dynamic>{
        'type': 'ride_request',
        'ride_request_type': 'regular',
        'vehicle_category_id': vehicleCategoryId,
        'pickup_address': pickupAddress,
        'destination_address': destinationAddress,
        'pickup_coordinates': pickupCoordinates,
        'destination_coordinates': destinationCoordinates,
      },
    );

    final bool succeeded = ApiClient.isSuccessCode(response.statusCode);
    if (succeeded) {
      final dynamic payload = ResponseParser.payloadOf(response.body);
      if (payload is Map) {
        _requestReference = payload['ref_id']?.toString();
      }
      _rideSubmitted = true;
      _fareOptions = <FareModel>[];
      _hasEstimatedFare = false;
    } else {
      _errorMessage =
          response.statusText ?? 'Unable to request this ride right now.';
    }

    _isRequestingRide = false;
    update();
    return succeeded;
  }

  Map<String, double>? _coordinates(AddressModel? address) {
    if (address == null) return null;
    final double? latitude = double.tryParse(address.latitude ?? '');
    final double? longitude = double.tryParse(address.longitude ?? '');
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return <String, double>{
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  void _clearQuote() {
    _fareOptions = <FareModel>[];
    _errorMessage = null;
    _rideSubmitted = false;
    _requestReference = null;
    update();
  }

}
