import 'package:fasta_deliveries/api/api_client.dart';
import 'package:fasta_deliveries/api/response_parser.dart';
import 'package:fasta_deliveries/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_location/domain/models/ride_details_model.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/domain/models/bidding_model.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/domain/models/ride_list_model.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/domain/services/ride_order_service_interface.dart';

enum RideState{initial, riseFare, findingRider, acceptingRider, afterAcceptRider, otpSent, ongoingRide, completeRide}
enum RideType{regularRide, scheduleRide}

class RideController extends GetxController implements GetxService {
  final RideOrderServiceInterface rideOrderServiceInterface;

  RideController({required this.rideOrderServiceInterface});

  RideDetails? tripDetails;
  RideDetails? rideDetails;

  List<Bidding> biddingList = [];
  bool haveRunningTrip = false;

  RideListModel? _runningRideList;
  RideListModel? get runningRideList => _runningRideList;

  RideListModel? _historyRideList;
  RideListModel? get historyRideList => _historyRideList;

  void updateRideController() {
  }

  void setRideGetMessage(bool value){
  }


  void updateRideCurrentState(RideState newState) {
  }

  /// The customer's rides for My Orders. The API pages all rides newest first; "running"
  /// (still moving, or finished but unpaid) and "history" are split here.
  Future<void> getRideList(int offset, {bool isUpdate = false, bool isRunning = true, bool fromHome = false}) async {
    final ApiClient apiClient = Get.find<ApiClient>();
    final Response response = await apiClient.getData('${AppConstants.tripList}?limit=20&offset=$offset', handleError: false);
    if (!ApiClient.isSuccessCode(response.statusCode)) {
      update();
      return;
    }
    final dynamic body = ResponseParser.payloadOf(response.body);
    if (body is! Map) return;
    final RideListModel page = RideListModel.fromJson(Map<String, dynamic>.from(body));
    bool running(RideDetails r) => const ['pending', 'accepted', 'ongoing'].contains(r.currentStatus)
        || (r.currentStatus == 'completed' && r.paymentStatus != 'paid');
    final List<RideDetails> rides = (page.data ?? <RideDetails>[]).where((r) => running(r) == isRunning).toList();

    RideListModel? current = isRunning ? _runningRideList : _historyRideList;
    if (offset == 1 || current == null) {
      current = RideListModel(responseCode: page.responseCode, message: page.message, totalSize: page.totalSize,
          limit: page.limit, offset: page.offset, data: rides);
    } else {
      current.data = [...?current.data, ...rides];
      current.offset = page.offset;
      current.totalSize = page.totalSize;
    }
    if (isRunning) {
      _runningRideList = current;
      haveRunningTrip = (current.data ?? const []).isNotEmpty;
    } else {
      _historyRideList = current;
    }
    update();
  }

  Future<Response> getCurrentRide({bool fromRefresh = false, bool navigateToMap = true}) async {
    return Response();
  }

  Future<Response> getRideDetails(String tripId, {bool isUpdate = true}) async {
    return Response();
  }

  Future<Response> getBiddingList(String tripId, int offset) async {
    return Response();
  }

  void startLocationRecord() {
  }

  void stopLocationRecord() {
  }


  Future<Response> getFinalFare(String tripId) async {
    return Response();
  }

  Future<Response> getCurrentRideStatus({bool fromRefresh = false, bool navigateToMap = true, bool showCustomLoader = false, showWarningToast = false}) async {
    return Response();
  }

  Future<Response> remainingDistance(String requestID,{bool mapBound = false}) async {
    return Response();
  }

  Future<Response> getNearestDriverList(String  lat, String lng) async {
    return Response();
  }

  void clearBiddingList(){
  }

  Future<bool> deleteRide(String? tripId) async {
    return false;
  }

  Future<bool> removeRideFromList(String? tripId) async {
    return false;
  }

}