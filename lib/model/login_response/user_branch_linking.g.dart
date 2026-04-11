// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_branch_linking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserBranchLinking _$UserBranchLinkingFromJson(Map<String, dynamic> json) =>
    UserBranchLinking(
      userType: (json['_userType'] as num?)?.toInt(),
      branchDetails: json['branchDetails'] == null
          ? null
          : BranchDetails.fromJson(
              json['branchDetails'] as Map<String, dynamic>),
      id: json['_id'] as String?,
      branchId: json['_branchId'] as String?,
    );

Map<String, dynamic> _$UserBranchLinkingToJson(UserBranchLinking instance) =>
    <String, dynamic>{
      '_userType': instance.userType,
      'branchDetails': instance.branchDetails,
      '_id': instance.id,
      '_branchId': instance.branchId,
    };
