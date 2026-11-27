import 'package:fasta_deliveries/features/service_module/service_home/domain/repositories/service_repository_interface.dart';
import 'package:get/get.dart';

import 'service_service_interface.dart';

class ServiceService implements ServiceServiceInterface {
  final ServiceRepositoryInterface serviceRepositoryInterface;
  ServiceService({required this.serviceRepositoryInterface});

  @override
  Future<Response> getServices({required int limit, required int offset}) {
    return serviceRepositoryInterface.getServices(limit: limit, offset: offset);
  }
}
