import 'package:json_annotation/json_annotation.dart';

part 'product_input.g.dart';

@JsonSerializable(explicitToJson: true)
class ProductInput {
  final int? limit;
  final int? skip;
  final String? searchingText;
  final int? sortOrder;
  final int? sortType;

  final List<int>? statusArray;
  final List<String>? productsIds;
  final List<int>? screenType;
  final List<String>? brandIds;
  final List<String>? categoryIds;
  final List<String>? collectionIds;

  final List<int>? isPublished;

  final int? priceRangeEnd;
  final int? priceRangeStart;

  final List<dynamic>? specifications;
  final List<String>? tagIds;
  final List<String>? variantIds;

  final List<String>? branchIds;

  final List<dynamic>? collection;
  final List<dynamic>? tag;
  final List<dynamic>? brand;
  final List<dynamic>? category;

  final int? imageLimit;

  ProductInput({
    this.limit,
    this.skip,
    this.searchingText,
    this.sortOrder,
    this.sortType,
    this.statusArray,
    this.productsIds,
    this.screenType,
    this.brandIds,
    this.categoryIds,
    this.collectionIds,
    this.isPublished,
    this.priceRangeEnd,
    this.priceRangeStart,
    this.specifications,
    this.tagIds,
    this.variantIds,
    this.branchIds,
    this.collection,
    this.tag,
    this.brand,
    this.category,
    this.imageLimit,
  });

  factory ProductInput.fromJson(Map<String, dynamic> json) =>
      _$ProductInputFromJson(json);

  Map<String, dynamic> toJson() => _$ProductInputToJson(this);
}
