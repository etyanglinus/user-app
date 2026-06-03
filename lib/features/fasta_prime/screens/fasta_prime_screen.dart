import 'package:fasta_deliveries/api/api_client.dart';
import 'package:fasta_deliveries/features/fasta_prime/controllers/fasta_prime_controller.dart';
import 'package:fasta_deliveries/features/fasta_prime/domain/models/fasta_prime_model.dart';
import 'package:fasta_deliveries/helper/price_converter.dart';
import 'package:fasta_deliveries/util/dimensions.dart';
import 'package:fasta_deliveries/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FastaPrimeScreen extends StatefulWidget {
  const FastaPrimeScreen({super.key});

  @override
  State<FastaPrimeScreen> createState() => _FastaPrimeScreenState();
}

class _FastaPrimeScreenState extends State<FastaPrimeScreen> {
  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<FastaPrimeController>()) {
      Get.put(FastaPrimeController(apiClient: Get.find<ApiClient>()));
    }
    Get.find<FastaPrimeController>().loadPrime();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fasta Prime')),
      body: GetBuilder<FastaPrimeController>(builder: (controller) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.loadPrime,
          child: ListView(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            children: [
              _PrimeStatusCard(controller: controller),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text('Choose your plan', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              if (controller.plans.isEmpty)
                _emptyCard(context)
              else
                ...controller.plans.map((plan) => _PlanCard(plan: plan, controller: controller)),
            ],
          ),
        );
      }),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: Theme.of(context).disabledColor.withValues(alpha: 0.2)),
      ),
      child: const Text('No Fasta Prime plans are available right now.'),
    );
  }
}

class _PrimeStatusCard extends StatelessWidget {
  final FastaPrimeController controller;
  const _PrimeStatusCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final subscription = controller.currentSubscription;
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: controller.isPrime ? Theme.of(context).primaryColor.withValues(alpha: 0.12) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.workspace_premium, color: Theme.of(context).primaryColor),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Text(controller.isPrime ? 'Active Fasta Prime' : 'Fasta Prime', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge))),
          if (controller.isPrime)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(20)),
              child: Text('Free delivery', style: robotoMedium.copyWith(color: Colors.white, fontSize: Dimensions.fontSizeSmall)),
            ),
        ]),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text(
          controller.isPrime
              ? 'Your membership is active${subscription?.endDate != null ? ' until ${subscription!.endDate}' : ''}.'
              : 'Subscribe to unlock free delivery benefits and member-only offers.',
          style: robotoRegular,
        ),
        if (controller.isPrime)
          TextButton(onPressed: controller.cancel, child: const Text('Cancel membership')),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final FastaPrimePlan plan;
  final FastaPrimeController controller;
  const _PlanCard({required this.plan, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(plan.name ?? 'Fasta Prime Plan', style: robotoBold.copyWith(fontSize: Dimensions.fontSizeLarge)),
        const SizedBox(height: Dimensions.paddingSizeExtraSmall),
        Text('${PriceConverter.convertPrice(plan.price ?? 0)} / ${plan.validityDays ?? 30} days', style: robotoMedium.copyWith(color: Theme.of(context).primaryColor)),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text(plan.description ?? 'Free delivery benefits apply automatically at checkout while your membership is active.', style: robotoRegular),
        const SizedBox(height: Dimensions.paddingSizeSmall),
        Text('Free deliveries: ${plan.freeDeliveryLimit == 0 ? 'Unlimited' : plan.freeDeliveryLimit}', style: robotoRegular),
        if ((plan.maxDeliveryDiscount ?? 0) > 0)
          Text('Delivery discount cap: ${PriceConverter.convertPrice(plan.maxDeliveryDiscount)}', style: robotoRegular),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: controller.isSubscribing ? null : () => controller.subscribe(plan),
            child: Text(controller.isSubscribing ? 'Please wait...' : 'Subscribe with wallet'),
          ),
        ),
      ]),
    );
  }
}
