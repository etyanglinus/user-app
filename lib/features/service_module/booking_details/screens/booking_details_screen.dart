import 'package:fasta_deliveries/common/widgets/custom_app_bar.dart';
import 'package:fasta_deliveries/common/widgets/custom_button.dart';
import 'package:fasta_deliveries/common/widgets/custom_snackbar.dart';
import 'package:fasta_deliveries/features/service_module/booking_details/controllers/booking_controller.dart';
import 'package:fasta_deliveries/features/service_module/booking_details/controllers/service_journey_controller.dart';
import 'package:fasta_deliveries/helper/price_converter.dart';
import 'package:fasta_deliveries/util/dimensions.dart';
import 'package:fasta_deliveries/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// One service booking: where it stands, who is coming, and cancel / rate.
class BookingDetailsScreen extends StatefulWidget {
  final int? bookingId;
  final bool fromNotification;
  final bool isSubBooking;
  final String? trackContactNumber;

  const BookingDetailsScreen({super.key,
    required this.bookingId, this.fromNotification = false, this.isSubBooking = false, this.trackContactNumber,
  });

  @override
  BookingDetailsScreenState createState() => BookingDetailsScreenState();
}

class BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final ServiceJourneyController _journey = Get.find<ServiceJourneyController>();
  final TextEditingController _comment = TextEditingController();
  int _stars = 0;

  static const List<String> _steps = ['pending', 'accepted', 'confirmed', 'ongoing', 'completed'];
  static const Map<String, String> _labels = {
    'pending': 'Waiting for the provider',
    'accepted': 'Accepted',
    'confirmed': 'Confirmed',
    'ongoing': 'In progress',
    'completed': 'Completed',
    'canceled': 'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    if (widget.bookingId != null) _journey.follow(widget.bookingId!);
  }

  @override
  void dispose() {
    _journey.stopFollowing();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(context: context, builder: (context) {
      final controller = TextEditingController();
      return AlertDialog(
        title: const Text('Cancel this booking?'),
        content: TextField(controller: controller, maxLength: 255, decoration: const InputDecoration(hintText: 'Reason (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('no'.tr)),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Cancel booking')),
        ],
      );
    });
    if (reason == null) return;
    final ok = await _journey.cancel(reason);
    if (ok) {
      Get.find<BookingController>().refreshBookingDetail(widget.bookingId ?? 0, notify: true);
    } else {
      showCustomSnackBar(_journey.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'booking_details'.tr),
      body: GetBuilder<ServiceJourneyController>(builder: (journey) {
        final b = journey.bookingId == widget.bookingId ? journey.booking : null;
        if (b == null) {
          return Center(child: journey.error != null ? Text(journey.error!) : const CircularProgressIndicator());
        }
        final status = journey.status;
        final hint = Theme.of(context).hintColor;
        final provider = b['provider'] is Map ? b['provider'] as Map : null;
        final workers = (b['servicemen'] as List?)?.whereType<Map>().toList() ?? const [];
        final location = b['service_location'] is Map ? b['service_location'] as Map : const {};
        final amount = b['amount'] is Map ? double.tryParse('${b['amount']['booking_amount']}') : double.tryParse('${b['booking_amount']}');
        final line = (b['details'] as List?)?.whereType<Map>().firstOrNull;

        return RefreshIndicator(
          onRefresh: journey.refresh,
          child: ListView(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            children: [
              Text('Booking #${b['display_id'] ?? b['id']}', style: robotoMedium.copyWith(color: hint)),
              Text(line?['service_name']?.toString() ?? '', style: robotoBold.copyWith(fontSize: 20)),
              if (provider != null) Text(provider['name']?.toString() ?? '', style: robotoRegular),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _Progress(status: status, steps: _steps, labels: _labels),
              if (status == 'canceled' && (b['cancellation_reason'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text('Reason: ${b['cancellation_reason']}', style: robotoRegular.copyWith(color: hint))),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(leading: const Icon(Icons.event), title: Text(b['schedule_at']?.toString() ?? 'As soon as possible')),
                  ListTile(leading: const Icon(Icons.location_on), title: Text(location['address']?.toString() ?? '')),
                  ListTile(
                    leading: const Icon(Icons.payments),
                    title: Text(PriceConverter.convertPrice(amount ?? 0)),
                    subtitle: Text(b['payment_status'] == 'paid' ? 'Paid' : 'Pay in cash after the service'),
                  ),
                ]),
              ),
              if (workers.isNotEmpty) ...[
                const SizedBox(height: Dimensions.paddingSizeDefault),
                Text('Who is coming', style: robotoBold),
                for (final w in workers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(w['name']?.toString() ?? ''),
                    trailing: (w['phone'] ?? '').toString().isEmpty || !ServiceJourneyController.active.contains(status)
                        ? null
                        : IconButton.filled(icon: const Icon(Icons.call), onPressed: () => launchUrl(Uri(scheme: 'tel', path: '${w['phone']}'))),
                  ),
              ],
              const SizedBox(height: Dimensions.paddingSizeLarge),
              if (journey.canCancel)
                CustomButton(buttonText: 'Cancel booking', transparent: true, isBorder: true, isLoading: journey.busy, onPressed: _cancel),
              if (journey.canRate) ...[
                Center(child: Text('How was the service?', style: robotoBold)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(iconSize: 34, tooltip: '$i', icon: Icon(i <= _stars ? Icons.star : Icons.star_border, color: Colors.amber),
                        onPressed: () => setState(() => _stars = i)),
                ]),
                TextField(controller: _comment, maxLength: 1000, maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Tell others about it (optional)', border: OutlineInputBorder())),
                CustomButton(
                  buttonText: 'submit'.tr,
                  isLoading: journey.busy,
                  onPressed: _stars == 0 ? null : () async {
                    final ok = await journey.rate(_stars, _comment.text);
                    showCustomSnackBar(ok ? 'Thanks for your review!' : journey.error, isError: !ok);
                  },
                ),
              ],
              if (status == 'completed' && b['is_reviewed'] == true)
                const Center(child: Padding(padding: EdgeInsets.all(8), child: Text('Thanks, your review was sent.'))),
            ],
          ),
        );
      }),
    );
  }
}

class _Progress extends StatelessWidget {
  final String status;
  final List<String> steps;
  final Map<String, String> labels;
  const _Progress({required this.status, required this.steps, required this.labels});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    if (status == 'canceled') {
      return Row(children: [Icon(Icons.cancel, color: Theme.of(context).colorScheme.error), const SizedBox(width: 8), Text(labels['canceled']!, style: robotoBold)]);
    }
    final reached = steps.indexOf(status);
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        Row(children: [
          Icon(i <= reached ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: i <= reached ? color : Theme.of(context).disabledColor),
          const SizedBox(width: 8),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(labels[steps[i]]!, style: i == reached ? robotoBold : robotoRegular))),
        ]),
    ]);
  }
}
