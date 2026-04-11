import 'package:json_annotation/json_annotation.dart';

import 'variant_detail.dart';

part 'product_list.g.dart';

@JsonSerializable()
class ProductList {
  @JsonKey(name: '_id')
  String? id;
  VariantDetail? variantDetail;
  @JsonKey(name: '__typename')
  String? typename;

  ProductList({this.id, this.variantDetail, this.typename});

  factory ProductList.fromJson(Map<String, dynamic> json) {
    return _$ProductListFromJson(json);
  }

  Map<String, dynamic> toJson() => _$ProductListToJson(this);
}
