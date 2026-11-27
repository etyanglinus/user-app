import 'package:get/get.dart';
import 'package:fasta_deliveries/api/api_client.dart';
import 'package:fasta_deliveries/api/response_parser.dart';
import 'package:fasta_deliveries/features/service_module/booking_details/domain/services/booking_service_interface.dart';

import '../domain/models/service_model.dart';
import '../domain/services/service_service_interface.dart';

class ServiceController extends GetxController implements GetxService {
  final ServiceServiceInterface serviceServiceInterface;
  final BookingServiceInterface bookingServiceInterface;
  ServiceController({required this.serviceServiceInterface, required this.bookingServiceInterface});

  static const int _pageSize = 20;
  List<Service> _services = [];
  List<Service> get services => _services;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = false;
  bool get hasMore => _hasMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _page = 1;

  Future<void> loadServices({bool refresh = false, bool append = false}) async {
    if (_isLoading || _isLoadingMore) return;
    if (!refresh && !append && _services.isNotEmpty) return;

    final int page = append ? _page + 1 : 1;
    _isLoading = !append;
    _isLoadingMore = append;
    _errorMessage = null;
    update();

    final response = await serviceServiceInterface.getServices(
      limit: _pageSize,
      offset: page,
    );

    if (ApiClient.isSuccessCode(response.statusCode)) {
      final dynamic payload = ResponseParser.payloadOf(response.body);
      if (payload is Map) {
        final ServiceModel result =
            ServiceModel.fromJson(Map<String, dynamic>.from(payload));
        final List<Service> loaded = result.services ?? <Service>[];
        _services = append ? <Service>[..._services, ...loaded] : loaded;
        _page = page;
        _hasMore = result.totalSize != null
            ? _services.length < result.totalSize!
            : loaded.length == _pageSize;
      } else {
        _errorMessage = 'The service catalogue returned an invalid response.';
      }
    } else {
      _errorMessage =
          response.statusText ?? 'Unable to load services right now.';
    }

    _isLoading = false;
    _isLoadingMore = false;
    update();
  }

  void toggleFavourite(Service service) {}
}
