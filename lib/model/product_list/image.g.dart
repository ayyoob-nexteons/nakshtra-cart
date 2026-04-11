// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Image _$ImageFromJson(Map<String, dynamic> json) => Image(
      url: json['_url'] as String?,
      id: json['_id'] as String?,
      isThumbnail: (json['_isThumbnail'] as num?)?.toInt(),
      typename: json['__typename'] as String?,
    );

Map<String, dynamic> _$ImageToJson(Image instance) => <String, dynamic>{
      '_url': instance.url,
      '_id': instance.id,
      '_isThumbnail': instance.isThumbnail,
      '__typename': instance.typename,
    };
