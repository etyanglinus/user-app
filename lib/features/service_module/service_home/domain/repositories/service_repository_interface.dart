import 'package:get/get.dart';

import '../../../../../interfaces/repository_interface.dart';

abstract class ServiceRepositoryInterface extends RepositoryInterface {
  Future<Response> getServices({required int limit, required int offset});
}
