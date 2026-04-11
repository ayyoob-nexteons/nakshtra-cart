import 'package:json_annotation/json_annotation.dart';

part 'cart_request.g.dart';

@JsonSerializable()
class CartRequest {
  int? skip;
  int? limit;
  String? searchingText;
  List<int>? statusArray;
  List<String>? branchIds;
  List<dynamic>? cartIds;
  List<dynamic>? customerIds;
  List<dynamic>? productIds;
  List<dynamic>? screenType;
  int? sortType;
  int? sortOrder;
  List<dynamic>? variantIds;
  String? skuSearch;

  CartRequest({
    this.skip,
    this.limit,
    this.searchingText,
    this.statusArray,
    this.branchIds,
    this.cartIds,
    this.customerIds,
    this.productIds,
    this.screenType,
    this.sortType,
    this.sortOrder,
    this.variantIds,
    this.skuSearch,
  });

  factory CartRequest.fromJson(Map<String, dynamic> json) {
    return _$CartRequestFromJson(json);
  }

  Map<String, dynamic> toJson() => _$CartRequestToJson(this);
}
