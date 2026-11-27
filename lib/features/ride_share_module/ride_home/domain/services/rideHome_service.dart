import '../repositories/rideHome_repository_interface.dart';
import 'rideHome_service_interface.dart';
import 'package:get/get.dart';

class RideHomeService implements RideHomeServiceInterface {
  final RideHomeRepositoryInterface rideHomeRepositoryInterface;
  RideHomeService({required this.rideHomeRepositoryInterface});

  @override
  Future<Response> estimateFare(Map<String, dynamic> body) {
    return rideHomeRepositoryInterface.estimateFare(body);
  }

  @override
  Future<Response> createRide(Map<String, dynamic> body) {
    return rideHomeRepositoryInterface.createRide(body);
  }
}
  