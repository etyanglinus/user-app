import 'package:fasta_deliveries/interfaces/repository_interface.dart';
import 'package:fasta_deliveries/util/html_type.dart';

abstract class HtmlRepositoryInterface extends RepositoryInterface {
  Future<dynamic> getHtmlText(HtmlType htmlType);
}