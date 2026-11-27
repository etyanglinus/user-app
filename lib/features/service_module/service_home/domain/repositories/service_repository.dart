import '../../../../../api/api_client.dart';
import 'package:fasta_deliveries/util/app_constants.dart';
import 'package:get/get.dart';
import 'service_repository_interface.dart';

class ServiceRepository implements ServiceRepositoryInterface {
  final ApiClient apiClient;
  ServiceRepository({required this.apiClient});

  @override
  Future<Response> getServices({required int limit, required int offset}) {
    return apiClient.getData(
      '${AppConstants.serviceQueryUri}?limit=$limit&offset=$offset',
      handleError: false,
      moduleScoped: true,
    );
  }

  @override Future add(value) { throw UnimplementedError(); }
  @override Future delete(int? id) { throw UnimplementedError(); }
  @override Future get(String? id) { throw UnimplementedError(); }
  @override Future getList({int? offset}) =>
      getServices(limit: 20, offset: offset ?? 1);
  @override Future update(Map<String, dynamic> body, int? id) { throw UnimplementedError(); }
}
