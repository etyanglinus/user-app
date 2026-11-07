import 'package:flutter/material.dart';
import 'package:fasta_deliveries/common/models/ongoing_order_model.dart';

class ServiceRunningBookingWidget extends StatelessWidget {
  final List<OrderData> bookings;
  final Function onTap;

  const ServiceRunningBookingWidget({super.key, required this.bookings, required this.onTap});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
