import 'package:fasta_deliveries/api/api_client.dart';
import 'package:fasta_deliveries/common/widgets/custom_snackbar.dart';
import 'package:fasta_deliveries/features/fasta_prime/domain/models/fasta_prime_model.dart';
import 'package:fasta_deliveries/util/app_constants.dart';
import 'package:get/get.dart';

class FastaPrimeController extends GetxController {
  final ApiClient apiClient;
  FastaPrimeController({required this.apiClient});

  bool isLoading = false;
  bool isSubscribing = false;
  bool isPrime = false;
  String? redirectLink;
  FastaPrimeSubscription? currentSubscription;
  List<FastaPrimePlan> plans = [];

  Future<void> loadPrime() async {
    isLoading = true;
    update();
    await Future.wait([getPlans(), getCurrent()]);
    isLoading = false;
    update();
  }

  Future<void> getPlans() async {
    final response = await apiClient.getData(AppConstants.fastaPrimePlansUri, handleError: false);
    if (response.statusCode == 200 && response.body['plans'] != null) {
      plans = [];
      response.body['plans'].forEach((plan) => plans.add(FastaPrimePlan.fromJson(plan)));
    }
  }

  Future<void> getCurrent() async {
    final response = await apiClient.getData(AppConstants.fastaPrimeCurrentUri, handleError: false);
    if (response.statusCode == 200) {
      isPrime = response.body['is_prime'] == true;
      currentSubscription = response.body['subscription'] != null ? FastaPrimeSubscription.fromJson(response.body['subscription']) : null;
    }
  }

  Future<void> subscribe(FastaPrimePlan plan, {String paymentMethod = 'wallet'}) async {
    if (plan.id == null) return;
    isSubscribing = true;
    redirectLink = null;
    update();

    final response = await apiClient.postData(AppConstants.fastaPrimeSubscribeUri, {
      'plan_id': plan.id.toString(),
      'payment_method': paymentMethod,
      'payment_platform': GetPlatform.isWeb ? 'web' : 'app',
    }, handleError: false);

    isSubscribing = false;
    if (response.statusCode == 200) {
      if (response.body['redirect_link'] != null) {
        redirectLink = response.body['redirect_link'].toString();
        showCustomSnackBar('Continue payment to activate Fasta Prime', isError: false);
      } else {
        showCustomSnackBar(response.body['message']?.toString() ?? 'Fasta Prime activated', isError: false);
        await getCurrent();
      }
    } else {
      showCustomSnackBar(response.statusText ?? 'Fasta Prime subscription failed');
    }
    update();
  }

  Future<void> cancel() async {
    final response = await apiClient.postData(AppConstants.fastaPrimeCancelUri, {}, handleError: false);
    if (response.statusCode == 200) {
      showCustomSnackBar(response.body['message']?.toString() ?? 'Fasta Prime canceled', isError: false);
      await getCurrent();
      update();
    } else {
      showCustomSnackBar(response.statusText ?? 'Unable to cancel Fasta Prime');
    }
  }
}
