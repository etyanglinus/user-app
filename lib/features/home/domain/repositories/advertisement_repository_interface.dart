import 'package:fasta_deliveries/common/enums/data_source_enum.dart';
import 'package:fasta_deliveries/features/home/domain/models/advertisement_model.dart';
import 'package:fasta_deliveries/interfaces/repository_interface.dart';

abstract class AdvertisementRepositoryInterface extends RepositoryInterface{
  @override
  Future<List<AdvertisementModel>?> getList({int? offset, DataSourceEnum source = DataSourceEnum.client});
}