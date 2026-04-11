// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartRequest _$CartRequestFromJson(Map<String, dynamic> json) => CartRequest(
      skip: (json['skip'] as num?)?.toInt(),
      limit: (json['limit'] as num?)?.toInt(),
      searchingText: json['searchingText'] as String?,
      statusArray: (json['statusArray'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      branchIds: (json['branchIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      cartIds: json['cartIds'] as List<dynamic>?,
      customerIds: json['customerIds'] as List<dynamic>?,
      productIds: json['productIds'] as List<dynamic>?,
      screenType: json['screenType'] as List<dynamic>?,
      sortType: (json['sortType'] as num?)?.toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
      variantIds: json['variantIds'] as List<dynamic>?,
      skuSearch: json['skuSearch'] as String?,
    );

Map<String, dynamic> _$CartRequestToJson(CartRequest instance) =>
    <String, dynamic>{
      'skip': instance.skip,
      'limit': instance.limit,
      'searchingText': instance.searchingText,
      'statusArray': instance.statusArray,
      'branchIds': instance.branchIds,
      'cartIds': instance.cartIds,
      'customerIds': instance.customerIds,
      'productIds': instance.productIds,
      'screenType': instance.screenType,
      'sortType': instance.sortType,
      'sortOrder': instance.sortOrder,
      'variantIds': instance.variantIds,
      'skuSearch': instance.skuSearch,
    };
