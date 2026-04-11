import 'package:json_annotation/json_annotation.dart';

part 'branch_details.g.dart';

@JsonSerializable()
class BranchDetails {
  @JsonKey(name: '_address')
  String? address;
  @JsonKey(name: '_name')
  String? name;
  @JsonKey(name: '_id')
  String? id;

  BranchDetails({this.address, this.name, this.id});

  factory BranchDetails.fromJson(Map<String, dynamic> json) {
    return _$BranchDetailsFromJson(json);
  }

  Map<String, dynamic> toJson() => _$BranchDetailsToJson(this);
}
