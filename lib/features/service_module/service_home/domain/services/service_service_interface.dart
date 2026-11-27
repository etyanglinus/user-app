import 'package:get/get.dart';

abstract class ServiceServiceInterface {
  Future<Response> getServices({required int limit, required int offset});
}
