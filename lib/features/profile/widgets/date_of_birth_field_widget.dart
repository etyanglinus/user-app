import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fasta_deliveries/util/dimensions.dart';
import 'package:fasta_deliveries/util/styles.dart';

/// Date of birth on Edit Profile (birthday rewards). The customer can set it once; after that
/// it is shown but locked, and support corrects it.
class DateOfBirthFieldWidget extends StatelessWidget {
  final String? value; // yyyy-MM-dd
  final bool locked;
  final ValueChanged<String> onChanged;

  const DateOfBirthFieldWidget({super.key, required this.value, required this.locked, required this.onChanged});

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String display(String? value) {
    final DateTime? date = value == null ? null : DateTime.tryParse(value);
    return date == null ? '' : '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime last = DateTime(now.year, now.month, now.day - 1);
    final DateTime initial = DateTime.tryParse(value ?? '') ?? DateTime(now.year - 25, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: DateTime(1900),
      lastDate: last,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'date_of_birth'.tr,
    );
    if (picked != null) {
      onChanged('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String text = display(value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: locked ? null : () => _pick(context),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'date_of_birth'.tr,
            prefixIcon: Icon(Icons.cake_outlined, color: Theme.of(context).hintColor),
            suffixIcon: Icon(locked ? Icons.lock_outline : Icons.calendar_month, color: Theme.of(context).hintColor, size: 20),
            enabled: !locked,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
          ),
          child: Text(
            text.isEmpty ? 'add_your_birthday'.tr : text,
            style: robotoRegular.copyWith(color: text.isEmpty ? Theme.of(context).hintColor : null),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        locked ? 'date_of_birth_locked_hint'.tr : 'date_of_birth_hint'.tr,
        style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).hintColor),
      ),
    ]);
  }
}
