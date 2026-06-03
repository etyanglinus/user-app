import 'package:get/get.dart';
import 'package:fasta_deliveries/util/html_type.dart';

abstract class HtmlServiceInterface{
  Future<Response> getHtmlText(HtmlType htmlType);
}