import 'package:json_annotation/json_annotation.dart';

import 'variant_details.dart';

part 'cart.g.dart';

@JsonSerializable()
class Cart {
  @JsonKey(name: '_id')
  String? id;
  @JsonKey(name: '_qty')
  int? qty;
  @JsonKey(name: '_status')
  int? status;
  @JsonKey(name: '_variantId')
  String? variantId;
  VariantDetails? variantDetails;

  @JsonKey(name: '_customerId')
  String? customerId;

  Cart({
    this.id,
    this.qty,
    this.status,
    this.variantId,
    this.variantDetails,
    this.customerId,
  });

  factory Cart.fromJson(Map<String, dynamic> json) => _$CartFromJson(json);

  Map<String, dynamic> toJson() => _$CartToJson(this);
}
