// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductInput _$ProductInputFromJson(Map<String, dynamic> json) => ProductInput(
      limit: (json['limit'] as num?)?.toInt(),
      skip: (json['skip'] as num?)?.toInt(),
      searchingText: json['searchingText'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
      sortType: (json['sortType'] as num?)?.toInt(),
      statusArray: (json['statusArray'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      productsIds: (json['productsIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      screenType: (json['screenType'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      brandIds: (json['brandIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      categoryIds: (json['categoryIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      collectionIds: (json['collectionIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      isPublished: (json['isPublished'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      priceRangeEnd: (json['priceRangeEnd'] as num?)?.toInt(),
      priceRangeStart: (json['priceRangeStart'] as num?)?.toInt(),
      specifications: json['specifications'] as List<dynamic>?,
      tagIds:
          (json['tagIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
      variantIds: (json['variantIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      branchIds: (json['branchIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      collection: json['collection'] as List<dynamic>?,
      tag: json['tag'] as List<dynamic>?,
      brand: json['brand'] as List<dynamic>?,
      category: json['category'] as List<dynamic>?,
      imageLimit: (json['imageLimit'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ProductInputToJson(ProductInput instance) =>
    <String, dynamic>{
      'limit': instance.limit,
      'skip': instance.skip,
      'searchingText': instance.searchingText,
      'sortOrder': instance.sortOrder,
      'sortType': instance.sortType,
      'statusArray': instance.statusArray,
      'productsIds': instance.productsIds,
      'screenType': instance.screenType,
      'brandIds': instance.brandIds,
      'categoryIds': instance.categoryIds,
      'collectionIds': instance.collectionIds,
      'isPublished': instance.isPublished,
      'priceRangeEnd': instance.priceRangeEnd,
      'priceRangeStart': instance.priceRangeStart,
      'specifications': instance.specifications,
      'tagIds': instance.tagIds,
      'variantIds': instance.variantIds,
      'branchIds': instance.branchIds,
      'collection': instance.collection,
      'tag': instance.tag,
      'brand': instance.brand,
      'category': instance.category,
      'imageLimit': instance.imageLimit,
    };
