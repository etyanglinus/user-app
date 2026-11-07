import 'package:flutter/material.dart';
import 'package:fasta_deliveries/helper/price_converter.dart';
import 'package:fasta_deliveries/util/dimensions.dart';
import 'package:fasta_deliveries/util/styles.dart';

class BogoBundlePriceText extends StatelessWidget {
  final double? bundlePrice;
  final int quantity;
  final double? fontSize;
  final Color? color;

  const BogoBundlePriceText({super.key,
    this.bundlePrice, this.quantity = 1, this.fontSize, this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double price = (bundlePrice ?? 0) * quantity;

    return Text(
      PriceConverter.convertPrice(price), textDirection: TextDirection.ltr,
      style: robotoBold.copyWith(fontSize: fontSize ?? Dimensions.fontSizeLarge, color: color),
    );
  }
}
