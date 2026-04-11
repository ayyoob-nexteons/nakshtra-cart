import 'package:json_annotation/json_annotation.dart';

part 'cart_status_model.g.dart';

@JsonSerializable()
class CartStatusModel {
  @JsonKey(name: 'cartId')
  final String cartId;

  @JsonKey(name: 'status')
  final int status;

  CartStatusModel({
    required this.cartId,
    required this.status,
  });

  factory CartStatusModel.fromJson(Map<String, dynamic> json) =>
      _$CartStatusModelFromJson(json);

  Map<String, dynamic> toJson() => _$CartStatusModelToJson(this);
}

