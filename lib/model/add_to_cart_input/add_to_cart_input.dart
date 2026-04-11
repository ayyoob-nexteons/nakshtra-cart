import 'package:json_annotation/json_annotation.dart';

import 'item.dart';

part 'add_to_cart_input.g.dart';

@JsonSerializable()
class AddToCartInput {
  String? branchId;
  List<Item>? items;
  String? customerId;

  AddToCartInput({this.branchId, this.items, this.customerId});

  factory AddToCartInput.fromJson(Map<String, dynamic> json) {
    return _$AddToCartInputFromJson(json);
  }

  Map<String, dynamic> toJson() => _$AddToCartInputToJson(this);
}
