import 'package:get/get.dart';
import 'package:fasta_deliveries/features/category/domain/services/category_service_interface.dart';
import 'package:fasta_deliveries/features/service_module/request_service/domain/services/requested_service_service_interface.dart';

class RequestedServiceController extends GetxController implements GetxService {
  final CategoryServiceInterface categoryServiceInterface;
  final RequestedServiceServiceInterface requestedServiceServiceInterface;

  RequestedServiceController({required this.categoryServiceInterface, required this.requestedServiceServiceInterface});
}
