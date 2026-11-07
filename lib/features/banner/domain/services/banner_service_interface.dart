import 'package:fasta_deliveries/common/enums/data_source_enum.dart';
import 'package:fasta_deliveries/features/banner/domain/models/banner_model.dart';
import 'package:fasta_deliveries/features/banner/domain/models/others_banner_model.dart';
import 'package:fasta_deliveries/features/banner/domain/models/promotional_banner_model.dart';

abstract class BannerServiceInterface {
  Future<BannerModel?> getBannerList({required DataSourceEnum source});
  Future<BannerModel?> getTaxiBannerList();
  Future<BannerModel?> getFeaturedBannerList();
  Future<ParcelOtherBannerModel?> getParcelOtherBannerList({required DataSourceEnum source});
  Future<PromotionalBanner?> getPromotionalBannerList();
  List<int?> moduleIdList();
}
