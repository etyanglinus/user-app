import 'package:fasta_deliveries/common/widgets/custom_app_bar.dart';
import 'package:fasta_deliveries/common/widgets/custom_button.dart';
import 'package:fasta_deliveries/common/widgets/custom_snackbar.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/controllers/ride_journey_controller.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/domain/models/customer_ride.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/screens/ride_order_complete_screen.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_payment/screens/ride_payment_screen.dart';
import 'package:fasta_deliveries/helper/price_converter.dart';
import 'package:fasta_deliveries/util/dimensions.dart';
import 'package:fasta_deliveries/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// The customer's open ride: finding a driver → driver on the way (with the pickup code) →
/// on the trip → done. Moves on to payment when the trip ends.
class RideTrackingScreen extends StatefulWidget {
  final String rideId;
  const RideTrackingScreen({super.key, required this.rideId});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final RideJourneyController _journey = Get.find<RideJourneyController>();
  bool _movedOn = false;

  @override
  void initState() {
    super.initState();
    _journey.follow(widget.rideId);
  }

  @override
  void dispose() {
    _journey.stopFollowing();
    super.dispose();
  }

  void _moveOnIfFinished(CustomerRide ride) {
    if (_movedOn || ride.status != CustomerRide.completed) return;
    _movedOn = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ride.needsPayment) {
        Get.off(() => RidePaymentScreen(rideId: ride.id));
      } else {
        Get.off(() => RideOrderCompleteScreen(tripId: ride.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'your_ride'.tr),
      body: GetBuilder<RideJourneyController>(builder: (journey) {
        final ride = journey.ride?.id == widget.rideId ? journey.ride : null;
        if (ride == null) {
          return Center(
            child: journey.error != null
                ? Padding(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(journey.error!, textAlign: TextAlign.center),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      TextButton(onPressed: () => journey.refreshRide(showLoading: true), child: Text('retry'.tr)),
                    ]),
                  )
                : const CircularProgressIndicator(),
          );
        }
        _moveOnIfFinished(ride);

        return RefreshIndicator(
          onRefresh: () => journey.refreshRide(),
          child: ListView(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            children: [
              _StatusBanner(ride: ride),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              if (ride.driver != null && ride.isActive) ...[
                _DriverCard(driver: ride.driver!),
                const SizedBox(height: Dimensions.paddingSizeDefault),
              ],
              if (ride.status == CustomerRide.accepted && (ride.otp ?? '').isNotEmpty) ...[
                _PickupCode(code: ride.otp!),
                const SizedBox(height: Dimensions.paddingSizeDefault),
              ],
              _RouteCard(ride: ride),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              if (ride.canCancel)
                CustomButton(
                  buttonText: 'cancel_ride'.tr,
                  transparent: true,
                  isBorder: true,
                  isLoading: journey.busy,
                  onPressed: () => _confirmCancel(context, journey),
                ),
              if (ride.status == CustomerRide.cancelled)
                CustomButton(buttonText: 'back_to_home'.tr, onPressed: () => Get.back()),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _confirmCancel(BuildContext context, RideJourneyController journey) async {
    await journey.loadCancelReasons();
    if (!context.mounted) return;
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _CancelSheet(reasons: journey.reasonsForRide),
    );
    if (reason == null) return;
    final ok = await journey.cancel(reason);
    if (!ok) showCustomSnackBar(journey.error);
  }
}

class _StatusBanner extends StatelessWidget {
  final CustomerRide ride;
  const _StatusBanner({required this.ride});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, String title, String subtitle) = switch (ride.status) {
      CustomerRide.pending => (Icons.search, 'Finding you a driver', 'Hang on, we are asking drivers near you.'),
      CustomerRide.accepted => (Icons.directions_car, 'Your driver is on the way', 'Share the pickup code when they arrive.'),
      CustomerRide.ongoing => (Icons.route, 'On your trip', 'Enjoy the ride.'),
      CustomerRide.completed => (Icons.check_circle, 'You have arrived', 'Thanks for riding with Fasta.'),
      _ => (
          Icons.cancel,
          'Ride cancelled',
          ride.cancellationReason?.isNotEmpty == true ? ride.cancellationReason! : 'This ride was cancelled.'
        ),
    };
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Row(children: [
        ride.status == CustomerRide.pending
            ? SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: theme.primaryColor))
            : Icon(icon, size: 28, color: theme.primaryColor),
        const SizedBox(width: Dimensions.paddingSizeDefault),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
            const SizedBox(height: 4),
            Text(subtitle, style: robotoRegular.copyWith(color: theme.hintColor)),
          ]),
        ),
      ]),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final RideDriverCard driver;
  const _DriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: (driver.image ?? '').startsWith('http') ? NetworkImage(driver.image!) : null,
            child: (driver.image ?? '').startsWith('http') ? null : const Icon(Icons.person),
          ),
          const SizedBox(width: Dimensions.paddingSizeDefault),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(driver.name, style: robotoBold),
              if (driver.rating != null)
                Row(children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  Text(' ${driver.rating!.toStringAsFixed(1)} (${driver.reviews})', style: robotoRegular),
                ]),
              if ((driver.vehicle ?? '').isNotEmpty || (driver.plate ?? '').isNotEmpty)
                Text([driver.vehicle, driver.plate].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                    style: robotoMedium.copyWith(color: theme.hintColor)),
            ]),
          ),
          if ((driver.phone ?? '').isNotEmpty)
            IconButton.filled(
              tooltip: 'call'.tr,
              icon: const Icon(Icons.call),
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: driver.phone)),
            ),
        ]),
      ),
    );
  }
}

class _PickupCode extends StatelessWidget {
  final String code;
  const _PickupCode({required this.code});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Column(children: [
          Text('Pickup code', style: robotoMedium),
          const SizedBox(height: 6),
          SelectableText(code, style: robotoBold.copyWith(fontSize: 30, letterSpacing: 8)),
          const SizedBox(height: 4),
          Text('Give this to your driver to start the trip.', style: robotoRegular.copyWith(color: Theme.of(context).hintColor)),
        ]),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final CustomerRide ride;
  const _RouteCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _place(Icons.my_location, ride.pickupAddress),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          _place(Icons.location_on, ride.destinationAddress),
          const Divider(height: Dimensions.paddingSizeLarge),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('fare'.tr, style: robotoMedium),
            Text(PriceConverter.convertPrice(ride.fare), style: robotoBold),
          ]),
        ]),
      ),
    );
  }

  Widget _place(IconData icon, String? text) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text ?? '', style: robotoRegular)),
      ]);
}

class _CancelSheet extends StatefulWidget {
  final List<String> reasons;
  const _CancelSheet({required this.reasons});

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, Dimensions.paddingSizeDefault),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Why are you cancelling?', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          RadioGroup<String>(
            groupValue: _picked,
            onChanged: (value) => setState(() => _picked = value),
            child: Column(children: [
              for (final reason in widget.reasons) RadioListTile<String>(value: reason, title: Text(reason), contentPadding: EdgeInsets.zero),
            ]),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          CustomButton(
            buttonText: 'cancel_ride'.tr,
            onPressed: widget.reasons.isEmpty || _picked != null ? () => Navigator.of(context).pop(_picked ?? '') : null,
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('keep_my_ride'.tr)),
        ]),
      ),
    );
  }
}
