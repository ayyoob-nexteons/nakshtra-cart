// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variant_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VariantDetails _$VariantDetailsFromJson(Map<String, dynamic> json) =>
    VariantDetails(
      displayName: json['_displayName'] as String?,
      id: json['_id'] as String?,
      name: json['_name'] as String?,
      status: (json['_status'] as num?)?.toInt(),
      sku: json['_sku'] as String?,
      shortDescription: json['_shortDescription'] as String?,
      qty: (json['_qty'] as num?)?.toInt(),
      productId: json['_productId'] as String?,
      metals: json['metals'] as List<dynamic>?,
    );

Map<String, dynamic> _$VariantDetailsToJson(VariantDetails instance) =>
    <String, dynamic>{
      '_displayName': instance.displayName,
      '_id': instance.id,
      '_name': instance.name,
      '_status': instance.status,
      '_sku': instance.sku,
      '_shortDescription': instance.shortDescription,
      '_qty': instance.qty,
      '_productId': instance.productId,
      'metals': instance.metals,
    };
