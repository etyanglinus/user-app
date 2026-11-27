import 'package:flutter/material.dart';
import 'package:fasta_deliveries/features/address/domain/models/address_model.dart';
import 'package:fasta_deliveries/features/location/screens/pick_map_screen.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_home/controllers/rideHome_controller.dart';
import 'package:fasta_deliveries/features/ride_share_module/ride_order/domain/models/estimated_fare_model.dart';
import 'package:fasta_deliveries/helper/address_helper.dart';
import 'package:fasta_deliveries/helper/auth_helper.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideHomeScreen extends StatefulWidget {
  static Future<void> loadData() async {
    if (AuthHelper.isLoggedIn()) {
      await Get.find<RideHomeController>().loadData();
    }
  }

  const RideHomeScreen({super.key});

  @override
  State<RideHomeScreen> createState() => _RideHomeScreenState();
}

class _RideHomeScreenState extends State<RideHomeScreen> {
  @override
  void initState() {
    super.initState();
    final RideHomeController controller = Get.find<RideHomeController>();
    if (controller.pickup == null) {
      final AddressModel? savedAddress =
          AddressHelper.getUserAddressFromSharedPref();
      if (savedAddress != null) {
        controller.setPickup(savedAddress);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<RideHomeController>(
      builder: (RideHomeController controller) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Ride-share',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your route and compare available ride options.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _LocationField(
                label: 'Pickup',
                address: controller.pickup,
                icon: Icons.my_location,
                onTap: () => _pickLocation(
                  context,
                  controller,
                  isPickup: true,
                ),
              ),
              const SizedBox(height: 10),
              _LocationField(
                label: 'Destination',
                address: controller.destination,
                icon: Icons.location_on_outlined,
                onTap: () => _pickLocation(
                  context,
                  controller,
                  isPickup: false,
                ),
              ),
              const SizedBox(height: 16),
              if (!AuthHelper.isLoggedIn())
                const _InfoMessage(
                  message: 'Sign in to get a fare estimate and request a ride.',
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !AuthHelper.isLoggedIn() ||
                          controller.pickup == null ||
                          controller.destination == null ||
                          controller.isLoadingFare ||
                          controller.isRequestingRide ||
                          controller.rideSubmitted
                      ? null
                      : () => controller.estimateFare(),
                  child: controller.isLoadingFare
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Get fare estimate'),
                ),
              ),
              if (controller.errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (controller.rideSubmitted) ...<Widget>[
                const SizedBox(height: 16),
                _InfoMessage(
                  message: controller.requestReference == null
                      ? 'Ride requested. We will notify you when a driver accepts.'
                      : 'Ride ${controller.requestReference} requested. We will notify you when a driver accepts.',
                ),
              ],
              if (controller.fareOptions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 20),
                Text(
                  'Available rides',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...controller.fareOptions.map(
                  (FareModel fare) => _FareOption(
                    fare: fare,
                    isRequesting: controller.isRequestingRide,
                    onRequest: () async {
                      if (await controller.requestRide(fare)) {
                        Get.snackbar(
                          'Ride requested',
                          'Your request has been sent to nearby drivers.',
                        );
                      }
                    },
                  ),
                ),
              ] else if (!controller.isLoadingFare &&
                  controller.errorMessage == null &&
                  controller.pickup != null &&
                  controller.destination != null &&
                  !controller.rideSubmitted) ...<Widget>[
                const SizedBox(height: 12),
                _InfoMessage(
                  message: controller.hasEstimatedFare
                      ? 'No ride options are available for this route right now.'
                      : 'Get an estimate to see ride options for this route.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLocation(
    BuildContext context,
    RideHomeController controller, {
    required bool isPickup,
  }) async {
    final AddressModel? currentAddress = isPickup
        ? controller.pickup
        : controller.destination ?? controller.pickup;
    final double? latitude =
        double.tryParse(currentAddress?.latitude ?? '');
    final double? longitude =
        double.tryParse(currentAddress?.longitude ?? '');
    final LatLng? initialPosition = latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PickMapScreen(
          fromSignUp: false,
          fromAddAddress: false,
          canRoute: false,
          route: null,
          initialPosition: initialPosition,
          initialAddress: currentAddress?.address,
          onPicked: (AddressModel address) {
            if (isPickup) {
              controller.setPickup(address);
            } else {
              controller.setDestination(address);
            }
          },
        ),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  final String label;
  final AddressModel? address;
  final IconData icon;
  final VoidCallback onTap;

  const _LocationField({
    required this.label,
    required this.address,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(
            address?.address?.isNotEmpty == true
                ? address!.address!
                : 'Tap to choose a location',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.map_outlined),
        ),
      );
}

class _FareOption extends StatelessWidget {
  final FareModel fare;
  final bool isRequesting;
  final VoidCallback onRequest;

  const _FareOption({
    required this.fare,
    required this.isRequesting,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final double amount = fare.estimatedFare ?? fare.fare ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.directions_car_outlined, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    fare.vehicleCategoryType ?? 'Ride',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${fare.estimatedDistance ?? '--'} km | '
                    '${fare.estimatedDuration ?? '--'} min',
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  'KES ${amount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: isRequesting ? null : onRequest,
                  child: isRequesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  final String message;

  const _InfoMessage({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(message),
      );
}
