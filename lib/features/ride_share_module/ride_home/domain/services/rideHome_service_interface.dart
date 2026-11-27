
import 'package:get/get.dart';

abstract class RideHomeServiceInterface {
  Future<Response> estimateFare(Map<String, dynamic> body);
  Future<Response> createRide(Map<String, dynamic> body);
}
