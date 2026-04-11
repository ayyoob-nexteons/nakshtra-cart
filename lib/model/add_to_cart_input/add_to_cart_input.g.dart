// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_to_cart_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddToCartInput _$AddToCartInputFromJson(Map<String, dynamic> json) =>
    AddToCartInput(
      branchId: json['branchId'] as String?,
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => Item.fromJson(e as Map<String, dynamic>))
          .toList(),
      customerId: json['customerId'] as String?,
    );

Map<String, dynamic> _$AddToCartInputToJson(AddToCartInput instance) =>
    <String, dynamic>{
      'branchId': instance.branchId,
      'items': instance.items,
      'customerId': instance.customerId,
    };
