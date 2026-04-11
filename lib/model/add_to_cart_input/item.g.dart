// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Item _$ItemFromJson(Map<String, dynamic> json) => Item(
      productId: json['productId'] as String?,
      qty: (json['qty'] as num?)?.toInt(),
      variantId: json['variantId'] as String?,
    );

Map<String, dynamic> _$ItemToJson(Item instance) => <String, dynamic>{
      'productId': instance.productId,
      'qty': instance.qty,
      'variantId': instance.variantId,
    };
