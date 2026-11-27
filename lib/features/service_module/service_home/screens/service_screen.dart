import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fasta_deliveries/features/service_module/service_home/controllers/service_controller.dart';
import 'package:fasta_deliveries/features/service_module/service_home/domain/models/service_model.dart';
import 'package:fasta_deliveries/features/dashboard/widgets/quick_filters_widget.dart';
import 'package:get/get.dart';
import 'package:sliver_tools/sliver_tools.dart';

class ServiceScreen extends StatefulWidget {
  final Key searchHeaderKey;
  final Key? exploreRestaurantKey;
  final ScrollController? scrollController;
  final bool isSearchPinned;

  const ServiceScreen({super.key,
    required this.searchHeaderKey, this.exploreRestaurantKey, this.scrollController, this.isSearchPinned = false,
  });

  static List<FoodModuleQuickFilterItem> get serviceQuickFilterItems => <FoodModuleQuickFilterItem>[];

  static void handleQuickFilterTap(FoodModuleQuickFilterItem item) {}

  static Future<void> loadData() async {
    await Get.find<ServiceController>().loadServices(refresh: true);
  }

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  @override
  void initState() {
    super.initState();
    Get.find<ServiceController>().loadServices();
  }

  // Rendered directly inside the dashboard's CustomScrollView (main_screen.dart),
  // so this must return a sliver — a plain box throws a RenderViewport type error.
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ServiceController>(
      builder: (controller) => MultiSliver(
        children: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Available services',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Explore services offered by providers on Fasta.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (controller.errorMessage != null &&
                      controller.services.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      controller.errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (controller.isLoading && controller.services.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (controller.errorMessage != null &&
              controller.services.isEmpty)
            SliverToBoxAdapter(
              child: _MessagePanel(
                message: controller.errorMessage!,
                actionLabel: 'Try again',
                onAction: () => controller.loadServices(refresh: true),
              ),
            )
          else if (controller.services.isEmpty)
            const SliverToBoxAdapter(
              child: _MessagePanel(
                message: 'No services are available right now.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) => _ServiceCard(
                    service: controller.services[index],
                  ),
                  childCount: controller.services.length,
                ),
              ),
            ),
          if (controller.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: controller.isLoadingMore
                      ? const CircularProgressIndicator()
                      : OutlinedButton(
                          onPressed: () =>
                              controller.loadServices(append: true),
                          child: const Text('Load more services'),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Service service;

  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = service.thumbnailFullUrl;
    final double? displayPrice = service.discountedPrice ?? service.basePrice;
    final String? priceText = displayPrice == null
        ? null
        : 'KES ${displayPrice.toStringAsFixed(0)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (BuildContext context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    service.name ?? 'Service',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (service.longDescription?.isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(service.longDescription!),
                  ],
                  if (priceText != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text('From $priceText'),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? Container(
                          color: Theme.of(context).cardColor,
                          child: const Icon(Icons.home_repair_service_outlined),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (BuildContext context, String url) =>
                              Container(
                            color: Theme.of(context).cardColor,
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.home_repair_service_outlined),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      service.name ?? 'Service',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (service.storeName?.isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        service.storeName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (service.shortDescription?.isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        service.shortDescription!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (priceText != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'From $priceText',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessagePanel({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      );
}
