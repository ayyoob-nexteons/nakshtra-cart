// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductList _$ProductListFromJson(Map<String, dynamic> json) => ProductList(
      id: json['_id'] as String?,
      variantDetail: json['variantDetail'] == null
          ? null
          : VariantDetail.fromJson(
              json['variantDetail'] as Map<String, dynamic>),
      typename: json['__typename'] as String?,
    );

Map<String, dynamic> _$ProductListToJson(ProductList instance) =>
    <String, dynamic>{
      '_id': instance.id,
      'variantDetail': instance.variantDetail,
      '__typename': instance.typename,
    };
