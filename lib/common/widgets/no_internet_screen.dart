import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fasta_deliveries/helper/route_helper.dart';
import 'package:fasta_deliveries/util/dimensions.dart';
import 'package:fasta_deliveries/util/images.dart';
import 'package:fasta_deliveries/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NoInternetScreen extends StatelessWidget {
  final Widget? child;
  const NoInternetScreen({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.of(context).size.height * 0.025),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(Images.noInternet, width: 220, height: 220),
            Text(
              'connection_unavailable'.tr,
              style: robotoBold.copyWith(
                fontSize: 24,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Text(
              'check_connection_and_retry'.tr,
              textAlign: TextAlign.center,
              style: robotoRegular.copyWith(
                color: Theme.of(context).disabledColor,
                fontSize: Dimensions.fontSizeDefault,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraLarge),

            GestureDetector(
              onTap: () async {
                final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

                if (!connectivityResult.contains(ConnectivityResult.none)) {
                  try {
                    Get.off(child);
                  } catch (e) {
                    Get.offAllNamed(RouteHelper.getInitialRoute());
                  }
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeLarge,
                  vertical: Dimensions.paddingSizeSmall,
                ),
                child: InkWell(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh, size: 20, color: Theme.of(context).cardColor),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Text(
                      'try_again'.tr,
                      style: robotoMedium.copyWith(color: Theme.of(context).cardColor),
                    ),
                  ]),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
