// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      email: json['_email'] as String?,
      id: json['_id'] as String?,
      name: json['_name'] as String?,
      status: (json['_status'] as num?)?.toInt(),
      userBranchLinkings: (json['userBranchLinkings'] as List<dynamic>?)
          ?.map((e) => UserBranchLinking.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      '_email': instance.email,
      '_id': instance.id,
      '_name': instance.name,
      '_status': instance.status,
      'userBranchLinkings': instance.userBranchLinkings,
    };
