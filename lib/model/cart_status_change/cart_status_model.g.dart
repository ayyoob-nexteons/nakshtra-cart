// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_status_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartStatusModel _$CartStatusModelFromJson(Map<String, dynamic> json) =>
    CartStatusModel(
      cartId: json['cartId'] as String,
      status: (json['status'] as num).toInt(),
    );

Map<String, dynamic> _$CartStatusModelToJson(CartStatusModel instance) =>
    <String, dynamic>{
      'cartId': instance.cartId,
      'status': instance.status,
    };
