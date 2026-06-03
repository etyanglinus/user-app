import 'package:fasta_deliveries/common/enums/data_source_enum.dart';
import 'package:fasta_deliveries/features/brands/domain/models/brands_model.dart';
import 'package:fasta_deliveries/features/item/domain/models/item_model.dart';

abstract class BrandsServiceInterface {
  Future<List<BrandModel>?> getBrandList(DataSourceEnum source);
  Future<ItemModel?> getBrandItemList({required int brandId, int? offset});
}