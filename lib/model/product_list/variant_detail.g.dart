// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'variant_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VariantDetail _$VariantDetailFromJson(Map<String, dynamic> json) =>
    VariantDetail(
      id: json['_id'] as String?,
      sku: json['_sku'] as String?,
      displayName: json['_displayName'] as String?,
      storePrice: (json['_storePrice'] as num?)?.toInt(),
      originalPrice: (json['_originalPrice'] as num?)?.toInt(),
      qty: (json['_qty'] as num?)?.toInt(),
      productId: json['_productId'] as String?,
      isInclusive: (json['_isInclusive'] as num?)?.toInt(),
      name: json['_name'] as String?,
      imageCount: (json['imageCount'] as num?)?.toInt(),
      isOutOfStockSellable: json['_isOutOfStockSellable'],
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => Image.fromJson(e as Map<String, dynamic>))
          .toList(),
      typename: json['__typename'] as String?,
    );

Map<String, dynamic> _$VariantDetailToJson(VariantDetail instance) =>
    <String, dynamic>{
      '_id': instance.id,
      '_sku': instance.sku,
      '_displayName': instance.displayName,
      '_storePrice': instance.storePrice,
      '_originalPrice': instance.originalPrice,
      '_qty': instance.qty,
      '_productId': instance.productId,
      '_isInclusive': instance.isInclusive,
      '_name': instance.name,
      'imageCount': instance.imageCount,
      '_isOutOfStockSellable': instance.isOutOfStockSellable,
      'images': instance.images,
      '__typename': instance.typename,
    };
