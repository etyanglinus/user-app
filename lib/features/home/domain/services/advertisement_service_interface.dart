import 'package:fasta_deliveries/common/enums/data_source_enum.dart';
import 'package:fasta_deliveries/features/home/domain/models/advertisement_model.dart';

abstract class AdvertisementServiceInterface {
  Future<List<AdvertisementModel>?> getAdvertisementList(DataSourceEnum source);
}