import 'package:get/get.dart';
import 'package:fasta_deliveries/features/splash/controllers/splash_controller.dart';
import 'package:fasta_deliveries/common/models/module_model.dart';
import 'package:fasta_deliveries/common/models/config_model.dart';

class ModuleHelper {

  static ModuleModel? getModule() {
    return Get.find<SplashController>().module;
  }

  static ModuleModel? getCacheModule() {
    return Get.find<SplashController>().getCacheModule();
  }

  static Module getModuleConfig(String? moduleType) {
    return Get.find<SplashController>().getModuleConfig(moduleType);
  }

}