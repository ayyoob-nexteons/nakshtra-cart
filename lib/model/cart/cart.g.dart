// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Cart _$CartFromJson(Map<String, dynamic> json) => Cart(
      id: json['_id'] as String?,
      qty: (json['_qty'] as num?)?.toInt(),
      status: (json['_status'] as num?)?.toInt(),
      variantId: json['_variantId'] as String?,
      variantDetails: json['variantDetails'] == null
          ? null
          : VariantDetails.fromJson(
              json['variantDetails'] as Map<String, dynamic>),
      customerId: json['_customerId'] as String?,
    );

Map<String, dynamic> _$CartToJson(Cart instance) => <String, dynamic>{
      '_id': instance.id,
      '_qty': instance.qty,
      '_status': instance.status,
      '_variantId': instance.variantId,
      'variantDetails': instance.variantDetails,
      '_customerId': instance.customerId,
    };
