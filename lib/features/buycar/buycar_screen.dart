import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:fasta_deliveries/api/api_client.dart';

class BuyCarScreen extends StatefulWidget {
  const BuyCarScreen({super.key});

  @override
  State<BuyCarScreen> createState() => BuyCarScreenState();
}

class BuyCarScreenState extends State<BuyCarScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _priceFormat = NumberFormat.currency(
    symbol: 'KES ',
    decimalDigits: 0,
  );
  List<Map<String, dynamic>> _cars = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _error;
  int _page = 1;
  String _sort = 'newest';
  String? _condition;
  String? _bodyType;
  String? _brandId;
  String _minPrice = '';
  String _maxPrice = '';

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCars({String? search, bool append = false}) async {
    final int page = append ? _page + 1 : 1;
    setState(() {
      _isLoading = !append;
      _isLoadingMore = append;
      _error = null;
      if (!append) {
        _cars = [];
        _hasMore = false;
      }
    });

    final queryParameters = <String, String>{
      'limit': '20',
      'offset': '$page',
      'sort': _sort,
      if (search?.trim().isNotEmpty == true) 'name': search!.trim(),
      if (_condition != null) 'condition': _condition!,
      if (_bodyType != null) 'body_type': _bodyType!,
      if (_brandId != null) 'brand_id': _brandId!,
      if (_minPrice.isNotEmpty) 'min_price': _minPrice,
      if (_maxPrice.isNotEmpty) 'max_price': _maxPrice,
    };
    final response = await Get.find<ApiClient>().getData(
      '/api/v1/buycar/vehicle/search?${Uri(queryParameters: queryParameters).query}',
      handleError: false,
    );

    if (!mounted) return;
    if (response.isOk) {
      final dynamic content = response.body is Map
          ? response.body['content']
          : null;
      final dynamic rows = content is Map ? content['data'] : null;
      final cars = rows is List
          ? rows.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      final dynamic pagination = content is Map ? content['pagination'] : null;
      final int? total = pagination is Map
          ? int.tryParse('${pagination['total_size']}')
          : null;
      setState(() {
        _cars = append ? [..._cars, ...cars] : cars;
        _page = page;
        _hasMore = total != null ? _cars.length < total : cars.length == 20;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = response.statusText ?? 'Unable to load cars right now.';
      });
    }
  }

  Future<void> refresh() => _loadCars(search: _searchController.text);

  Future<void> _openFilters() async {
    final filter = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BuyCarFilterSheet(
        condition: _condition,
        bodyType: _bodyType,
        brandId: _brandId,
        sort: _sort,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
      ),
    );
    if (filter == null || !mounted) return;
    setState(() {
      _condition = filter['condition'];
      _bodyType = filter['body_type'];
      _brandId = filter['brand_id'];
      _sort = filter['sort'] ?? 'newest';
      _minPrice = filter['min_price'] ?? '';
      _maxPrice = filter['max_price'] ?? '';
    });
    _loadCars(search: _searchController.text);
  }

  void _openBuyerArea(String section) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BuyCarBuyerAreaScreen(section: section),
      ),
    );
  }

  Future<void> _showCar(Map<String, dynamic> car) async {
    final response = await Get.find<ApiClient>().getData(
      '/api/v1/buycar/vehicle/get-vehicle-details/${car['id']}',
      handleError: false,
    );
    if (!mounted) return;
    if (!response.isOk) {
      _showMessage(response.statusText ?? 'Unable to load vehicle details.');
      return;
    }
    final dynamic content = response.body is Map
        ? response.body['content']
        : null;
    if (content is! Map) {
      _showMessage('Vehicle details are unavailable.');
      return;
    }

    final details = Map<String, dynamic>.from(content);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CarDetailsSheet(
        car: details,
        priceFormat: _priceFormat,
        onOffer: () => _submitBuyerAction(
          'offers',
          {'vehicle_id': details['id']},
          title: 'Make an offer',
          fieldLabel: 'Your offer (KES)',
          fieldName: 'offer_amount',
        ),
        onViewing: () => _requestViewing(details['id']),
        onWishlist: () => _wishlist(details['id']),
        onQuestion: () => _askQuestion(details['id']),
      ),
    );
  }

  Future<void> _wishlist(dynamic vehicleId) async {
    final response = await Get.find<ApiClient>().postData(
      '/api/v1/buycar/user/wish-list/add',
      {'vehicle_id': vehicleId},
      handleError: false,
    );
    _showMessage(
      response.isOk
          ? 'Car saved to your wishlist.'
          : response.statusText ?? 'Sign in to save cars.',
    );
  }

  Future<void> _requestViewing(dynamic vehicleId) async {
    final request = await _viewingRequestDialog();
    if (request == null) return;
    final response = await Get.find<ApiClient>().postData(
      '/api/v1/buycar/user/viewings',
      {'vehicle_id': vehicleId, ...request},
      handleError: false,
    );
    _showMessage(
      response.isOk
          ? 'Request sent to the seller.'
          : response.statusText ?? 'Unable to request this appointment.',
    );
  }

  Future<Map<String, dynamic>?> _viewingRequestDialog() async {
    final messageController = TextEditingController();
    final licenseController = TextEditingController();
    String type = 'viewing';
    DateTime scheduledAt = DateTime.now().add(const Duration(days: 1));
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request an appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Appointment'),
                  items: const [
                    DropdownMenuItem(value: 'viewing', child: Text('Viewing')),
                    DropdownMenuItem(
                      value: 'test_drive',
                      child: Text('Test drive'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? 'viewing'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DateFormat('EEE, d MMM yyyy • h:mm a').format(scheduledAt),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: scheduledAt,
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(scheduledAt),
                    );
                    if (time != null) {
                      setDialogState(
                        () => scheduledAt = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
                ),
                if (type == 'test_drive')
                  TextField(
                    controller: licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Driving licence number',
                    ),
                  ),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message to seller (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (type == 'test_drive' &&
                    licenseController.text.trim().isEmpty) {
                  _showMessage('Enter your driving licence number.');
                  return;
                }
                Navigator.pop(context, {
                  'requested_at': scheduledAt.toUtc().toIso8601String(),
                  'type': type,
                  if (messageController.text.trim().isNotEmpty)
                    'buyer_message': messageController.text.trim(),
                  if (type == 'test_drive')
                    'buyer_license_number': licenseController.text.trim(),
                });
              },
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    messageController.dispose();
    licenseController.dispose();
    return request;
  }

  Future<void> _askQuestion(dynamic vehicleId) async {
    final response = await Get.find<ApiClient>().getData(
      '/api/v1/buycar/vehicle/questions/$vehicleId?limit=20&offset=1',
      handleError: false,
    );
    if (!mounted) return;
    if (!response.isOk) {
      _showMessage(response.statusText ?? 'Unable to load vehicle questions.');
      return;
    }
    final body = response.body;
    final content = body is Map ? body['content'] : null;
    final data = content is Map ? content['data'] : null;
    final questions = data is List
        ? data.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
    final controller = TextEditingController();
    final question = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Questions & answers'),
        content: SizedBox(
          width: 480,
          height: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: questions.isEmpty
                    ? const Text('Be the first to ask the seller a question.')
                    : ListView(
                        shrinkWrap: true,
                        children: questions
                            .map(
                              (item) => ListTile(
                                title: Text(item['question']?.toString() ?? ''),
                                subtitle: Text(
                                  item['answer']?.toString() ??
                                      'Waiting for seller response',
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: 'Your question'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send question'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (question == null || question.isEmpty) return;
    final result = await Get.find<ApiClient>().postData(
      '/api/v1/buycar/user/question',
      {'vehicle_id': vehicleId, 'question': question},
      handleError: false,
    );
    _showMessage(
      result.isOk
          ? 'Question sent to the seller.'
          : result.statusText ?? 'Unable to send your question.',
    );
  }

  Future<void> _submitBuyerAction(
    String endpoint,
    Map<String, dynamic> body, {
    required String title,
    required String fieldLabel,
    required String fieldName,
  }) async {
    final controller = TextEditingController();
    final messageController = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: fieldLabel),
            ),
            if (endpoint == 'offers')
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message to seller (optional)',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    final offerMessage = messageController.text.trim();
    controller.dispose();
    messageController.dispose();
    if (value == null || value.isEmpty) return;

    final response = await Get.find<ApiClient>().postData(
      '/api/v1/buycar/user/$endpoint',
      {
        ...body,
        fieldName: value,
        if (endpoint == 'offers' && offerMessage.isNotEmpty)
          'buyer_message': offerMessage,
      },
      handleError: false,
    );
    if (!mounted) return;
    _showMessage(
      response.isOk
          ? 'Your request has been sent to the seller.'
          : response.statusText ?? 'Unable to send your request.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find your next car',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse verified listings and contact sellers directly.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _loadCars(search: value),
                  decoration: InputDecoration(
                    hintText: 'Search cars',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          _loadCars(search: _searchController.text),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune),
                      label: const Text('Filters'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openBuyerArea('wishlist'),
                      icon: const Icon(Icons.favorite_border),
                      label: const Text('Saved cars'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openBuyerArea('activity'),
                      icon: const Icon(Icons.event_note),
                      label: const Text('My requests'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null && _cars.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loadCars,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_cars.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No cars found. Try another search.')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.builder(
              itemCount: _cars.length,
              itemBuilder: (context, index) {
                final car = _cars[index];
                final image = car['thumbnail_full_url']?.toString() ?? '';
                final brand = car['brand'] is Map
                    ? car['brand']['name']?.toString()
                    : null;
                final title = [
                  brand,
                  car['model']?.toString(),
                  car['model_year']?.toString(),
                ].where((part) => part != null && part.isNotEmpty).join(' ');
                return Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _showCar(car),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (image.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: image,
                            height: 190,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            memCacheWidth: 720,
                            placeholder: (context, url) => const SizedBox(
                              height: 190,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) =>
                                const SizedBox(
                                  height: 190,
                                  child: Center(
                                    child: Icon(Icons.directions_car, size: 48),
                                  ),
                                ),
                          )
                        else
                          const SizedBox(
                            height: 160,
                            child: Center(
                              child: Icon(Icons.directions_car, size: 48),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                car['name']?.toString() ?? title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(title),
                              const SizedBox(height: 8),
                              Text(
                                _priceFormat.format(
                                  num.tryParse('${car['sale_price']}') ?? 0,
                                ),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${car['mileage'] ?? 0} km  •  ${car['condition'] ?? ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_error != null && _cars.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () =>
                        _loadCars(search: _searchController.text, append: true),
                    child: const Text('Retry loading more'),
                  ),
                ],
              ),
            ),
          ),
        if (!_isLoading && _error == null && _hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: OutlinedButton(
                onPressed: _isLoadingMore
                    ? null
                    : () => _loadCars(
                        search: _searchController.text,
                        append: true,
                      ),
                child: _isLoadingMore
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Load more vehicles'),
              ),
            ),
          ),
      ],
    );
  }
}

class _CarDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> car;
  final NumberFormat priceFormat;
  final VoidCallback onOffer;
  final VoidCallback onViewing;
  final VoidCallback onWishlist;
  final VoidCallback onQuestion;

  const _CarDetailsSheet({
    required this.car,
    required this.priceFormat,
    required this.onOffer,
    required this.onViewing,
    required this.onWishlist,
    required this.onQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final images = car['images_full_url'] is List
        ? (car['images_full_url'] as List).whereType<String>().toList()
        : <String>[];
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            if (images.isNotEmpty)
              SizedBox(
                height: 230,
                child: PageView(
                  children: images
                      .map(
                        (url) => CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          memCacheWidth: 900,
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              car['name']?.toString() ?? 'Vehicle details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              priceFormat.format(num.tryParse('${car['sale_price']}') ?? 0),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              [
                car['model_year'],
                car['condition'],
                '${car['mileage'] ?? 0} km',
                car['body_type'],
                car['body_color'],
              ].where((value) => value != null).join('  •  '),
            ),
            if (car['description'] != null) ...[
              const SizedBox(height: 12),
              Text(car['description'].toString()),
            ],
            if (car['registration_number'] != null)
              Text('Registration: ${car['registration_number']}'),
            if (car['vin_number'] != null) Text('VIN: ${car['vin_number']}'),
            if (car['provider'] is Map && car['provider']['name'] != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.storefront_outlined),
                title: Text(car['provider']['name'].toString()),
                subtitle: Text(
                  car['provider']['address']?.toString() ?? 'Seller',
                ),
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onViewing();
                  },
                  icon: const Icon(Icons.event_available),
                  label: const Text('Request viewing'),
                ),
                if (car['price_negotiable'] == true)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onOffer();
                    },
                    icon: const Icon(Icons.local_offer_outlined),
                    label: const Text('Make offer'),
                  ),
                IconButton(
                  tooltip: 'Save car',
                  onPressed: onWishlist,
                  icon: const Icon(Icons.favorite_border),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onQuestion();
                  },
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Ask seller'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Payment is arranged directly between buyer and seller. Fasta does not collect the vehicle sale price.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BuyCarFilterSheet extends StatefulWidget {
  final String? condition;
  final String? bodyType;
  final String? brandId;
  final String sort;
  final String minPrice;
  final String maxPrice;

  const _BuyCarFilterSheet({
    required this.condition,
    required this.bodyType,
    required this.brandId,
    required this.sort,
    required this.minPrice,
    required this.maxPrice,
  });

  @override
  State<_BuyCarFilterSheet> createState() => _BuyCarFilterSheetState();
}

class _BuyCarFilterSheetState extends State<_BuyCarFilterSheet> {
  late final TextEditingController _minPrice;
  late final TextEditingController _maxPrice;
  late String _sort;
  String? _condition;
  String? _bodyType;
  String? _brandId;
  List<Map<String, dynamic>> _brands = [];
  String? _brandError;

  @override
  void initState() {
    super.initState();
    _minPrice = TextEditingController(text: widget.minPrice);
    _maxPrice = TextEditingController(text: widget.maxPrice);
    _sort = widget.sort;
    _condition = widget.condition;
    _bodyType = widget.bodyType;
    _brandId = widget.brandId;
    _loadBrands();
  }

  @override
  void dispose() {
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    final response = await Get.find<ApiClient>().getData(
      '/api/v1/buycar/vehicle/brand-list?limit=100&offset=1',
      handleError: false,
    );
    if (!mounted) return;
    final body = response.body;
    final content = body is Map ? body['content'] : null;
    final rows = content is Map ? content['data'] : null;
    setState(() {
      if (response.isOk && rows is List) {
        _brands = rows.whereType<Map>().map(Map<String, dynamic>.from).toList();
      } else {
        _brandError = response.statusText ?? 'Unable to load vehicle brands.';
      }
    });
  }

  void _apply() {
    final min = num.tryParse(_minPrice.text.trim());
    final max = num.tryParse(_maxPrice.text.trim());
    if (min != null && max != null && min > max) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum price cannot exceed maximum price.'),
        ),
      );
      return;
    }
    Navigator.pop(context, <String, String?>{
      'condition': _condition,
      'body_type': _bodyType,
      'brand_id': _brandId,
      'sort': _sort,
      'min_price': _minPrice.text.trim(),
      'max_price': _maxPrice.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filter vehicles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _condition,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: const [
                  DropdownMenuItem(value: 'new', child: Text('New')),
                  DropdownMenuItem(value: 'used', child: Text('Used')),
                ],
                onChanged: (value) => setState(() => _condition = value),
              ),
              DropdownButtonFormField<String>(
                value: _bodyType,
                decoration: const InputDecoration(labelText: 'Body type'),
                items:
                    const [
                          'saloon',
                          'suv',
                          'hatchback',
                          'pickup',
                          'van',
                          'wagon',
                          'coupe',
                          'convertible',
                          'mpv',
                          'bus',
                          'truck',
                          'other',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value.replaceAll('_', ' ').toUpperCase(),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _bodyType = value),
              ),
              DropdownButtonFormField<String>(
                value: _brands.any((brand) => '${brand['id']}' == '$_brandId')
                    ? _brandId
                    : '',
                decoration: InputDecoration(
                  labelText: 'Brand',
                  helperText: _brandError,
                ),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Any')),
                  ..._brands.map((brand) {
                    final id = '${brand['id']}';
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(brand['name']?.toString() ?? 'Brand'),
                    );
                  }),
                ],
                onChanged: (value) => setState(
                  () =>
                      _brandId = value == null || value.isEmpty ? null : value,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPrice,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min price (KES)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxPrice,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max price (KES)',
                      ),
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _sort,
                decoration: const InputDecoration(labelText: 'Sort by'),
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(
                    value: 'price_asc',
                    child: Text('Price: low to high'),
                  ),
                  DropdownMenuItem(
                    value: 'price_desc',
                    child: Text('Price: high to low'),
                  ),
                  DropdownMenuItem(
                    value: 'year_desc',
                    child: Text('Newest model year'),
                  ),
                  DropdownMenuItem(
                    value: 'mileage_asc',
                    child: Text('Lowest mileage'),
                  ),
                  DropdownMenuItem(
                    value: 'popular',
                    child: Text('Most viewed'),
                  ),
                ],
                onChanged: (value) => setState(() => _sort = value ?? 'newest'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, <String, String?>{
                      'condition': null,
                      'body_type': null,
                      'brand_id': null,
                      'sort': 'newest',
                      'min_price': '',
                      'max_price': '',
                    }),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _apply,
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BuyCarBuyerAreaScreen extends StatelessWidget {
  final String section;

  const BuyCarBuyerAreaScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    if (section == 'wishlist') {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved cars')),
        body: const _BuyerRecordsPage(title: 'Saved cars', path: 'wish-list'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My BuyCar requests')),
      body: const DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: 'Offers'),
                Tab(text: 'Appointments'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BuyerRecordsPage(title: 'My offers', path: 'offers'),
                  _BuyerRecordsPage(title: 'My appointments', path: 'viewings'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuyerRecordsPage extends StatefulWidget {
  final String title;
  final String path;

  const _BuyerRecordsPage({required this.title, required this.path});

  @override
  State<_BuyerRecordsPage> createState() => _BuyerRecordsPageState();
}

class _BuyerRecordsPageState extends State<_BuyerRecordsPage> {
  late Future<Response> _request;

  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Response> _load() => Get.find<ApiClient>().getData(
    '/api/v1/buycar/user/${widget.path}?limit=30&offset=1',
    handleError: false,
  );

  Future<void> _refresh() async {
    final request = _load();
    setState(() => _request = request);
    await request;
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final id = row['id'];
    final api = Get.find<ApiClient>();
    final response = widget.path == 'wish-list'
        ? await api.deleteData(
            '/api/v1/buycar/user/wish-list/remove?vehicle_id=${row['vehicle_id'] ?? id}',
            handleError: false,
          )
        : await api.putData(
            '/api/v1/buycar/user/${widget.path}/$id/cancel',
            {},
            handleError: false,
          );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.isOk
              ? (widget.path == 'wish-list'
                    ? 'Removed from saved cars.'
                    : 'Request cancelled.')
              : response.statusText ?? 'Unable to update this request.',
        ),
      ),
    );
    if (response.isOk) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Response>(
      future: _request,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final response = snapshot.data;
        if (response == null || !response.isOk) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  response?.statusText ??
                      'Unable to load ${widget.title.toLowerCase()}.',
                ),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }
        final body = response.body;
        final content = body is Map ? body['content'] : null;
        final data = content is Map ? content['data'] : null;
        final rows = data is List
            ? data.whereType<Map>().map(Map<String, dynamic>.from).toList()
            : <Map<String, dynamic>>[];
        if (rows.isEmpty)
          return Center(child: Text('No ${widget.title.toLowerCase()} yet.'));
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final vehicle = row['vehicle'] is Map
                  ? Map<String, dynamic>.from(row['vehicle'] as Map)
                  : row;
              final status = row['status']?.toString() ?? 'saved';
              final isWishlist = widget.path == 'wish-list';
              final canCancel = isWishlist || status == 'pending';
              final subtitle = widget.path == 'offers'
                  ? 'KES ${row['offer_amount'] ?? ''} • $status'
                  : widget.path == 'viewings'
                  ? '${row['type'] ?? 'viewing'} • ${row['scheduled_at'] ?? row['requested_at'] ?? ''} • $status'
                  : 'KES ${vehicle['sale_price'] ?? ''}';
              return Card(
                child: ListTile(
                  leading: vehicle['thumbnail_full_url'] == null
                      ? const Icon(Icons.directions_car)
                      : CircleAvatar(
                          backgroundImage: NetworkImage(
                            vehicle['thumbnail_full_url'].toString(),
                          ),
                        ),
                  title: Text(vehicle['name']?.toString() ?? 'Vehicle'),
                  subtitle: Text(subtitle),
                  trailing: canCancel
                      ? IconButton(
                          tooltip: isWishlist
                              ? 'Remove saved car'
                              : 'Cancel request',
                          onPressed: () => _cancel(row),
                          icon: Icon(
                            isWishlist
                                ? Icons.delete_outline
                                : Icons.cancel_outlined,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
