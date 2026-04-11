import 'package:json_annotation/json_annotation.dart';

part 'image.g.dart';

@JsonSerializable()
class Image {
  @JsonKey(name: '_url')
  String? url;
  @JsonKey(name: '_id')
  String? id;
  @JsonKey(name: '_isThumbnail')
  int? isThumbnail;
  @JsonKey(name: '__typename')
  String? typename;

  Image({this.url, this.id, this.isThumbnail, this.typename});

  factory Image.fromJson(Map<String, dynamic> json) => _$ImageFromJson(json);

  Map<String, dynamic> toJson() => _$ImageToJson(this);
}
