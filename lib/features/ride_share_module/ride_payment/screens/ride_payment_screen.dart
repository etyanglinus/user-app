import 'package:fasta_deliveries/common/widgets/custom_app_bar.dart';
import 'package:fasta_deliveries/common/widgets/custom_button.dart';
import 'package:fasta_deliveries/common/widgets/custom_snackbar.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/controllers/ride_journey_controller.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/domain/models/customer_ride.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/screens/ride_order_complete_screen.dart';
import 'package:fasta_deliveries/helper/price_converter.dart';
import 'package:fasta_deliveries/util/dimensions.dart';
import 'package:fasta_deliveries/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Paying for a finished ride: wallet pays here; cash is handed to the driver, who confirms it
/// in their app, and this screen moves on to the rating once that shows up.
class RidePaymentScreen extends StatefulWidget {
  final String rideId;
  const RidePaymentScreen({super.key, required this.rideId});

  @override
  State<RidePaymentScreen> createState() => _RidePaymentScreenState();
}

class _RidePaymentScreenState extends State<RidePaymentScreen> {
  final RideJourneyController _journey = Get.find<RideJourneyController>();
  String _method = 'cash';
  bool _movedOn = false;

  @override
  void initState() {
    super.initState();
    _journey.follow(widget.rideId);
    _journey.loadPaymentOptions();
  }

  @override
  void dispose() {
    _journey.stopFollowing();
    super.dispose();
  }

  void _moveOnIfPaid(CustomerRide ride) {
    if (_movedOn || !ride.isPaid) return;
    _movedOn = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Get.off(() => RideOrderCompleteScreen(tripId: ride.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'payment'.tr),
      body: GetBuilder<RideJourneyController>(builder: (journey) {
        final ride = journey.ride?.id == widget.rideId ? journey.ride : null;
        if (ride == null) {
          return Center(child: journey.error != null ? Text(journey.error!) : const CircularProgressIndicator());
        }
        _moveOnIfPaid(ride);
        final waitingForDriver = ride.paymentMethod == 'cash' && !ride.isPaid;

        return ListView(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          children: [
            Center(child: Text('Trip fare', style: robotoMedium.copyWith(color: Theme.of(context).hintColor))),
            Center(child: Text(PriceConverter.convertPrice(ride.fare), style: robotoBold.copyWith(fontSize: 34))),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            if (waitingForDriver) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  child: Row(children: [
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                    const SizedBox(width: Dimensions.paddingSizeDefault),
                    Expanded(
                      child: Text('Pay ${PriceConverter.convertPrice(ride.fare)} in cash to your driver. '
                          'This screen moves on once they confirm it.'),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              if (journey.paymentOptions.any((o) => o.name == 'wallet'))
                TextButton(onPressed: () => setState(() => _method = 'wallet'), child: const Text('Pay from my wallet instead')),
            ],
            if (!waitingForDriver || _method == 'wallet') ...[
              Text('How would you like to pay?', style: robotoBold),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              RadioGroup<String>(
                groupValue: _method,
                onChanged: (value) => setState(() => _method = value ?? 'cash'),
                child: Column(children: [
                  for (final option in journey.paymentOptions)
                    RadioListTile<String>(
                      value: option.name,
                      title: Text(option.title),
                      subtitle: option.balance == null ? null : Text('Balance ${PriceConverter.convertPrice(option.balance)}'),
                      contentPadding: EdgeInsets.zero,
                    ),
                ]),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              CustomButton(
                buttonText: _method == 'wallet' ? 'Pay ${PriceConverter.convertPrice(ride.fare)}' : 'I will pay cash',
                isLoading: journey.busy,
                onPressed: () async {
                  final ok = await journey.pay(_method);
                  if (!ok) showCustomSnackBar(journey.error);
                },
              ),
            ],
          ],
        );
      }),
    );
  }
}
