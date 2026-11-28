import 'package:fasta_deliveries/common/widgets/custom_app_bar.dart';
import 'package:fasta_deliveries/common/widgets/custom_button.dart';
import 'package:fasta_deliveries/common/widgets/custom_snackbar.dart';
import 'package:fasta_deliveries/features/address/domain/models/address_model.dart';
import 'package:fasta_deliveries/features/location/screens/pick_map_screen.dart';
import 'package:fasta_deliveries/features/service_module/booking_details/controllers/service_journey_controller.dart';
import 'package:fasta_deliveries/features/service_module/booking_details/screens/booking_details_screen.dart';
import 'package:fasta_deliveries/features/service_module/service_home/domain/models/service_model.dart';
import 'package:fasta_deliveries/helper/address_helper.dart';
import 'package:fasta_deliveries/helper/auth_helper.dart';
import 'package:fasta_deliveries/helper/price_converter.dart';
import 'package:fasta_deliveries/util/dimensions.dart';
import 'package:fasta_deliveries/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Book one service: how many, where, and when (as soon as possible or a chosen time).
/// Payment is cash after the service.
class ServiceBookingScreen extends StatefulWidget {
  final Service service;
  const ServiceBookingScreen({super.key, required this.service});

  @override
  State<ServiceBookingScreen> createState() => _ServiceBookingScreenState();
}

class _ServiceBookingScreenState extends State<ServiceBookingScreen> {
  int _quantity = 1;
  AddressModel? _address = AddressHelper.getUserAddressFromSharedPref();
  DateTime? _when;

  double get _unit => widget.service.discountedPrice ?? widget.service.basePrice ?? 0;

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, firstDate: now, initialDate: now.add(const Duration(days: 1)), lastDate: now.add(const Duration(days: 60)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (picked.isBefore(now.add(const Duration(minutes: 30)))) {
      showCustomSnackBar('Choose a time at least 30 minutes from now.');
      return;
    }
    setState(() => _when = picked);
  }

  Future<void> _pickAddress() async {
    final lat = double.tryParse(_address?.latitude ?? '');
    final lng = double.tryParse(_address?.longitude ?? '');
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => PickMapScreen(
        fromSignUp: false,
        fromAddAddress: false,
        canRoute: false,
        route: null,
        initialPosition: lat == null || lng == null ? null : LatLng(lat, lng),
        initialAddress: _address?.address,
        onPicked: (AddressModel picked) => setState(() => _address = picked),
      ),
    ));
  }

  Future<void> _book(ServiceJourneyController journey) async {
    final id = widget.service.id;
    final lat = double.tryParse(_address?.latitude ?? '');
    final lng = double.tryParse(_address?.longitude ?? '');
    final address = _address?.address?.trim() ?? '';
    if (id == null) return;
    if (lat == null || lng == null || address.isEmpty) {
      showCustomSnackBar('Choose where the service should happen.');
      return;
    }
    final bookingId = await journey.place(serviceId: id, quantity: _quantity, address: address, lat: lat, lng: lng, scheduleAt: _when);
    if (bookingId == null) {
      showCustomSnackBar(journey.error);
      return;
    }
    Get.off(() => BookingDetailsScreen(bookingId: bookingId));
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Scaffold(
      appBar: CustomAppBar(title: 'book_service'.tr),
      body: GetBuilder<ServiceJourneyController>(builder: (journey) {
        return ListView(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          children: [
            Text(widget.service.name ?? '', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
            if ((widget.service.storeName ?? '').isNotEmpty) Text(widget.service.storeName!, style: robotoRegular.copyWith(color: hint)),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            Row(children: [
              Expanded(child: Text('How many?', style: robotoMedium)),
              IconButton.outlined(onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null, icon: const Icon(Icons.remove)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$_quantity', style: robotoBold.copyWith(fontSize: 18))),
              IconButton.outlined(onPressed: _quantity < 100 ? () => setState(() => _quantity++) : null, icon: const Icon(Icons.add)),
            ]),
            const Divider(height: Dimensions.paddingSizeExtraLarge),
            Text('Where', style: robotoMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on),
              title: Text(_address?.address ?? 'Choose an address', maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: TextButton(onPressed: _pickAddress, child: Text('change'.tr)),
            ),
            const Divider(height: Dimensions.paddingSizeExtraLarge),
            Text('When', style: robotoMedium),
            RadioGroup<bool>(
              groupValue: _when != null,
              onChanged: (later) => later == true ? _pickTime() : setState(() => _when = null),
              child: Column(children: [
                const RadioListTile<bool>(value: false, title: Text('As soon as possible'), contentPadding: EdgeInsets.zero),
                RadioListTile<bool>(
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_when == null ? 'Choose a date and time' : MaterialLocalizations.of(context).formatFullDate(_when!)),
                  subtitle: _when == null ? null : Text(TimeOfDay.fromDateTime(_when!).format(context)),
                ),
              ]),
            ),
            const Divider(height: Dimensions.paddingSizeExtraLarge),
            Row(children: [
              Expanded(child: Text('Total', style: robotoMedium)),
              Text(PriceConverter.convertPrice(_unit * _quantity), style: robotoBold.copyWith(fontSize: 20)),
            ]),
            Text('Pay in cash after the service.', style: robotoRegular.copyWith(color: hint)),
            const SizedBox(height: Dimensions.paddingSizeLarge),
            CustomButton(
              buttonText: AuthHelper.isLoggedIn() ? 'Book now' : 'Sign in to book',
              isLoading: journey.busy,
              onPressed: AuthHelper.isLoggedIn() ? () => _book(journey) : null,
            ),
          ],
        );
      }),
    );
  }
}
