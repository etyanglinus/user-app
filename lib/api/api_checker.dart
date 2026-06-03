import 'package:fasta_deliveries/features/favourite/controllers/favourite_controller.dart';
import 'package:fasta_deliveries/features/auth/controllers/auth_controller.dart';
import 'package:fasta_deliveries/helper/route_helper.dart';
import 'package:fasta_deliveries/common/widgets/custom_snackbar.dart';
import 'package:get/get.dart';

class ApiChecker {
  static void checkApi(Response response, {bool getXSnackBar = false}) {
    if(response.statusCode == 401) {
      Get.find<AuthController>().clearSharedData(removeToken: false).then((value) {
        Get.find<FavouriteController>().removeFavourite();
        Get.offAllNamed(RouteHelper.getInitialRoute());
      });
    } else {
      if(response.statusText != 'The guest id field is required.') {
        showCustomSnackBar(_friendlyMessage(response), getXSnackBar: getXSnackBar);
      }
    }
  }

  static String _friendlyMessage(Response response) {
    final String message = response.statusText ?? '';
    if(response.statusCode == 1 || response.statusCode == 0) {
      return 'service_temporarily_unavailable'.tr;
    }
    if(response.statusCode != null && response.statusCode! >= 500) {
      return 'we_could_not_reach_the_service'.tr;
    }
    if(message.toLowerCase().contains('server error') || message.toLowerCase().contains('internal server')) {
      return 'we_could_not_reach_the_service'.tr;
    }
    return message.isNotEmpty ? message : 'sorry_something_went_wrong'.tr;
  }
}
