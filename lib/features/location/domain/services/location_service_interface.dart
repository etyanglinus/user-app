import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fasta_deliveries/features/location/domain/models/prediction_model.dart';
import 'package:fasta_deliveries/features/address/domain/models/address_model.dart';
import 'package:fasta_deliveries/features/location/domain/models/zone_response_model.dart';
import 'package:fasta_deliveries/common/widgets/adaptive_map/adaptive_map.dart';

abstract class LocationServiceInterface{
  Future<Position> getPosition(LatLng? defaultLatLng, LatLng configLatLng);
  void handleMapAnimation(AdaptiveMapController? mapController, Position myPosition);
  Future<String> getAddressFromGeocode(LatLng latLng);
  Future<ZoneResponseModel> getZone(String? lat, String? lng, {bool handleError = false});
  Map<String, String> prepareHeader(List<int>? zoneIds);
  void configureFirebaseMessaging(AddressModel address);
  void handleRoute(bool fromSignUp, String? route, bool canRoute);
  Future<LatLng> getLatLng(String? id);
  Future<List<PredictionModel>> searchLocation(String text);
  void checkLocationPermission(Function onTap);
  Future<void> authorizeNavigation(String page, List<AddressModel>? addressList, AdaptiveMapController? mapController, {bool offNamed = false, bool offAll = false});
  void defaultNavigation(String page, AdaptiveMapController? mapController);
  String? getUserAddress();
  List<AddressModel> getRecentDeliveryAddresses();
  Future<List<AddressModel>> addRecentDeliveryAddress(AddressModel address);
}