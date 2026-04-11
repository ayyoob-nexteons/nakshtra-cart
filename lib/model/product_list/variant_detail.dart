import 'package:json_annotation/json_annotation.dart';

import 'image.dart';

part 'variant_detail.g.dart';

@JsonSerializable()
class VariantDetail {
  @JsonKey(name: '_id')
  String? id;
  @JsonKey(name: '_sku')
  String? sku;
  @JsonKey(name: '_displayName')
  String? displayName;
  @JsonKey(name: '_storePrice')
  int? storePrice;
  @JsonKey(name: '_originalPrice')
  int? originalPrice;
  @JsonKey(name: '_qty')
  int? qty;
  @JsonKey(name: '_productId')
  String? productId;
  @JsonKey(name: '_isInclusive')
  int? isInclusive;
  @JsonKey(name: '_name')
  String? name;
  int? imageCount;
  @JsonKey(name: '_isOutOfStockSellable')
  dynamic isOutOfStockSellable;
  List<Image>? images;
  @JsonKey(name: '__typename')
  String? typename;

  VariantDetail({
    this.id,
    this.sku,
    this.displayName,
    this.storePrice,
    this.originalPrice,
    this.qty,
    this.productId,
    this.isInclusive,
    this.name,
    this.imageCount,
    this.isOutOfStockSellable,
    this.images,
    this.typename,
  });

  factory VariantDetail.fromJson(Map<String, dynamic> json) {
    return _$VariantDetailFromJson(json);
  }

  Map<String, dynamic> toJson() => _$VariantDetailToJson(this);
}
