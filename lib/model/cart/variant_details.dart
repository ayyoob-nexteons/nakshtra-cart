import 'package:json_annotation/json_annotation.dart';

part 'variant_details.g.dart';

@JsonSerializable()
class VariantDetails {
  @JsonKey(name: '_displayName')
  String? displayName;
  @JsonKey(name: '_id')
  String? id;
  @JsonKey(name: '_name')
  String? name;
  @JsonKey(name: '_status')
  int? status;
  @JsonKey(name: '_sku')
  String? sku;
  @JsonKey(name: '_shortDescription')
  String? shortDescription;
  @JsonKey(name: '_qty')
  int? qty;
  @JsonKey(name: '_productId')
  String? productId;
  List<dynamic>? metals;

  VariantDetails({
    this.displayName,
    this.id,
    this.name,
    this.status,
    this.sku,
    this.shortDescription,
    this.qty,
    this.productId,
    this.metals,
  });

  factory VariantDetails.fromJson(Map<String, dynamic> json) {
    return _$VariantDetailsFromJson(json);
  }

  Map<String, dynamic> toJson() => _$VariantDetailsToJson(this);
}
