
import 'package:get/get.dart';

import '../../../../../interfaces/repository_interface.dart';

abstract class RideHomeRepositoryInterface extends RepositoryInterface {
  Future<Response> estimateFare(Map<String, dynamic> body);
  Future<Response> createRide(Map<String, dynamic> body);
}
  