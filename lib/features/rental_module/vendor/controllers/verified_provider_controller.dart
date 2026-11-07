import 'package:get/get.dart';
import 'package:fasta_deliveries/features/rental_module/vendor/domain/services/verified_provider_service_interface.dart';


class VerifiedProviderController extends GetxController implements GetxService {
  final VerifiedProviderServiceInterface verifiedProviderServiceInterface;

  VerifiedProviderController({required this.verifiedProviderServiceInterface});

}
