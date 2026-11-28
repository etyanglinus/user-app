import 'package:get/get.dart';
import 'package:fasta_deliveries/api/api_client.dart';
import 'package:fasta_deliveries/api/response_parser.dart';
import 'package:fasta_deliveries/common/models/ongoing_order_model.dart';
import 'package:fasta_deliveries/features/service_module/booking_details/domain/models/booking_model.dart';
import 'package:fasta_deliveries/features/service_module/booking_details/domain/services/booking_service_interface.dart';
import 'package:fasta_deliveries/util/app_constants.dart';

/// The customer's service bookings for My Orders (all / running / previous).
class BookingController extends GetxController implements GetxService {
  final BookingServiceInterface bookingServiceInterface;

  BookingController({required this.bookingServiceInterface});

  final Map<BookingListType, PaginatedBookingModel> _lists = {};

  List<OrderData>? get dashboardRunningBookings => null;

  PaginatedBookingModel? bookingModelOf(BookingListType type) => _lists[type];

  Future<void> getBookings(BookingListType type, int offset, {bool isUpdate = false, bool notify = true}) async {
    final String status = switch (type) {
      BookingListType.running => 'running',
      BookingListType.previous => 'history',
      BookingListType.all => 'all',
    };
    final response = await Get.find<ApiClient>().getData(
      '${AppConstants.serviceBookingListUri}?status=$status&limit=20&offset=$offset',
      handleError: false,
    );
    final data = ResponseParser.payloadOf(response.body);
    if (!ApiClient.isSuccessCode(response.statusCode) || data is! Map) {
      if (notify) update();
      return;
    }
    final page = PaginatedBookingModel.fromJson(Map<String, dynamic>.from(data));
    final current = _lists[type];
    _lists[type] = (offset == 1 || current == null)
        ? page
        : PaginatedBookingModel(
            totalSize: page.totalSize,
            limit: page.limit,
            offset: page.offset,
            bookings: [...?current.bookings, ...?page.bookings],
          );
    if (notify) update();
  }

  Future<void> getDashboardRunningBookings() async {}

  /// Hiding a finished booking is not offered by the API yet.
  Future<bool> deleteBooking(int id) async => false;

  void removeBookingFromList(int? id, {List<BookingListType> listTypes = BookingListType.values}) {
    for (final type in listTypes) {
      final list = _lists[type];
      if (list?.bookings == null) continue;
      _lists[type] = PaginatedBookingModel(totalSize: list!.totalSize, limit: list.limit, offset: list.offset,
          bookings: list.bookings!.where((b) => b.id != id).toList());
    }
    update();
  }

  Future<void> refreshBookingDetail(int id, {bool notify = false}) async {
    for (final type in BookingListType.values) {
      if (_lists.containsKey(type)) await getBookings(type, 1, notify: false);
    }
    if (notify) update();
  }
}
