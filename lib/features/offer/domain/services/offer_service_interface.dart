import 'package:fasta_deliveries/features/offer/domain/models/new_item_model.dart';
import 'package:fasta_deliveries/features/service_module/service_home/domain/models/service_model.dart';
import 'package:fasta_deliveries/features/store/domain/models/store_model.dart';

abstract class OfferServiceInterface {
  Future<NewItemListResponse?> getOfferItems({required int offset, int limit, String search, int? moduleId});
  Future<ServiceModel?> getServiceOfferItems({required int offset, int limit, String search, int? moduleId});
  Future<StoreModel?> getOfferStores({required int offset, int limit, String search, int? moduleId});
  Future<List<Store>?> getExclusiveDeals({int? moduleId});
}
