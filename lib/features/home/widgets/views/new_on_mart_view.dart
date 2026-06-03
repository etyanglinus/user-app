import 'package:fasta_deliveries/common/widgets/card_design/item_card.dart';
import 'package:fasta_deliveries/features/item/controllers/item_controller.dart';
import 'package:fasta_deliveries/features/item/domain/models/item_model.dart';
import 'package:fasta_deliveries/features/splash/controllers/splash_controller.dart';
import 'package:fasta_deliveries/features/home/widgets/web/web_new_on_view_widget.dart';
import 'package:fasta_deliveries/util/app_constants.dart';
import 'package:fasta_deliveries/util/dimensions.dart';
import 'package:fasta_deliveries/common/widgets/title_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NewOnMartView extends StatelessWidget {
  final bool isPharmacy;
  final bool isShop;
  final bool isNewStore;
  const NewOnMartView({super.key, required this.isPharmacy, required this.isShop, this.isNewStore = false});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ItemController>(builder: (itemController) {
      List<Item>? itemList = itemController.latestItemList;
      bool isFood = Get.find<SplashController>().module != null && Get.find<SplashController>().module!.moduleType.toString() == AppConstants.food;
      bool isShopModule = Get.find<SplashController>().module != null && Get.find<SplashController>().module!.moduleType.toString() == AppConstants.ecommerce;

      return itemList != null ? itemList.isNotEmpty ? Padding(
        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
        child: Column(children: [

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            child: TitleWidget(
              title: isShopModule ? 'new_products'.tr : 'recently_uploaded'.tr,
            ),
          ),

          SizedBox(
            height: 285,
            child: ListView.builder(
              controller: ScrollController(),
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
              itemCount: itemList.length,
              itemBuilder: (context, index){
                return Padding(
                  padding: const EdgeInsets.only(right: Dimensions.paddingSizeDefault, bottom: Dimensions.paddingSizeSmall, top: Dimensions.paddingSizeSmall),
                  child: ItemCard(
                    item: itemList[index],
                    isFood: isFood,
                    isShop: isShopModule,
                  ),
                );
              },
            ),
          ),
        ]),
      ) : const SizedBox.shrink() : const WebNewOnShimmerView();
    });
  }
}
