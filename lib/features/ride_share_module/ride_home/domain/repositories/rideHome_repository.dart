   
import 'package:get/get.dart';
import 'package:fasta_deliveries/util/app_constants.dart';

import '../../../../../api/api_client.dart';
import 'rideHome_repository_interface.dart';

class RideHomeRepository implements RideHomeRepositoryInterface {
  final ApiClient apiClient;
  RideHomeRepository({required this.apiClient});

  @override
  Future<Response> estimateFare(Map<String, dynamic> body) {
    return apiClient.postData(
      AppConstants.estimatedFare,
      body,
      handleError: false,
    );
  }

  @override
  Future<Response> createRide(Map<String, dynamic> body) {
    return apiClient.postData(
      AppConstants.rideRequest,
      body,
      handleError: false,
    );
  }

  @override
  Future add(value) {
    // TODO: implement add
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future get(String? id) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset}) {
    // TODO: implement getList
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    // TODO: implement update
    throw UnimplementedError();
  }

}
  