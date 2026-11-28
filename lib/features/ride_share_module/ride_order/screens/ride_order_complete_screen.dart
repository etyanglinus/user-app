import 'package:fasta_deliveries/common/widgets/custom_app_bar.dart';
import 'package:fasta_deliveries/common/widgets/custom_button.dart';
import 'package:fasta_deliveries/common/widgets/custom_snackbar.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/controllers/ride_journey_controller.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/domain/models/customer_ride.dart';
import 'package:fasta_deliveries/helper/price_converter.dart';
import 'package:fasta_deliveries/util/dimensions.dart';
import 'package:fasta_deliveries/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A finished (or cancelled) ride: what it cost, and a rating for the driver if not given yet.
class RideOrderCompleteScreen extends StatefulWidget {
  final String tripId;
  final bool fromNotification;
  final bool? fromRideList;
  const RideOrderCompleteScreen({super.key, required this.tripId, this.fromNotification = false, this.fromRideList = false});

  @override
  State<RideOrderCompleteScreen> createState() => _RideOrderCompleteScreenState();
}

class _RideOrderCompleteScreenState extends State<RideOrderCompleteScreen> {
  final RideJourneyController _journey = Get.find<RideJourneyController>();
  final TextEditingController _feedback = TextEditingController();
  int _stars = 0;
  bool _rated = false;

  @override
  void initState() {
    super.initState();
    _journey.follow(widget.tripId);
  }

  @override
  void dispose() {
    _journey.stopFollowing();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'trip_details'.tr),
      body: GetBuilder<RideJourneyController>(builder: (journey) {
        final ride = journey.ride?.id == widget.tripId ? journey.ride : null;
        if (ride == null) {
          return Center(child: journey.error != null ? Text(journey.error!) : const CircularProgressIndicator());
        }
        final cancelled = ride.status == CustomerRide.cancelled;
        final canRate = ride.status == CustomerRide.completed && !ride.reviewSubmitted && !_rated && ride.driver != null;

        return ListView(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          children: [
            Icon(cancelled ? Icons.cancel : Icons.check_circle, size: 64, color: cancelled ? Theme.of(context).colorScheme.error : Theme.of(context).primaryColor),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Center(child: Text(cancelled ? 'Ride cancelled' : 'Trip complete', style: robotoBold.copyWith(fontSize: 22))),
            if (cancelled && (ride.cancellationReason ?? '').isNotEmpty)
              Center(child: Text(ride.cancellationReason!, style: robotoRegular.copyWith(color: Theme.of(context).hintColor))),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                child: Column(children: [
                  _row('From', ride.pickupAddress ?? ''),
                  _row('To', ride.destinationAddress ?? ''),
                  if (ride.driver != null) _row('Driver', ride.driver!.name),
                  if (!cancelled) _row('Fare', PriceConverter.convertPrice(ride.fare)),
                  if (!cancelled) _row('Payment', ride.isPaid ? 'Paid${ride.paymentMethod == null ? '' : ' (${ride.paymentMethod})'}' : 'Not paid yet'),
                ]),
              ),
            ),
            if (canRate) ...[
              const SizedBox(height: Dimensions.paddingSizeLarge),
              Center(child: Text('How was your ride with ${ride.driver!.name}?', style: robotoBold)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 36,
                    tooltip: '$i',
                    icon: Icon(i <= _stars ? Icons.star : Icons.star_border, color: Colors.amber),
                    onPressed: () => setState(() => _stars = i),
                  ),
              ]),
              TextField(
                controller: _feedback,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Anything to add? (optional)', border: OutlineInputBorder()),
              ),
              CustomButton(
                buttonText: 'submit'.tr,
                isLoading: journey.busy,
                onPressed: _stars == 0
                    ? null
                    : () async {
                        final ok = await journey.rate(_stars, _feedback.text);
                        if (ok) {
                          setState(() => _rated = true);
                          showCustomSnackBar('Thanks for your rating!', isError: false);
                        } else {
                          showCustomSnackBar(journey.error);
                        }
                      },
              ),
            ],
            if (_rated || ride.reviewSubmitted) ...[
              const SizedBox(height: Dimensions.paddingSizeDefault),
              const Center(child: Text('Thanks, your rating was sent.')),
            ],
          ],
        );
      }),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 80, child: Text(label, style: robotoMedium)),
          Expanded(child: Text(value, style: robotoRegular)),
        ]),
      );
}
