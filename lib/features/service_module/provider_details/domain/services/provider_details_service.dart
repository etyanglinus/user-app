import 'package:fasta_deliveries/features/service_module/provider_details/domain/repositories/provider_details_repository_interface.dart';
import 'package:fasta_deliveries/features/service_module/provider_details/domain/services/provider_details_service_interface.dart';

class ProviderDetailsService implements ProviderDetailsServiceInterface {
  final ProviderDetailsRepositoryInterface providerDetailsRepositoryInterface;
  ProviderDetailsService({required this.providerDetailsRepositoryInterface});
}
