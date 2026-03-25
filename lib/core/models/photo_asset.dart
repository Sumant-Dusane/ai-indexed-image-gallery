import 'package:freezed_annotation/freezed_annotation.dart';

part 'photo_asset.freezed.dart';
part 'photo_asset.g.dart';

@freezed
class PhotoAsset with _$PhotoAsset {
  const factory PhotoAsset({
    required String id,
    String? localPath,
    DateTime? takenAt,
    int? width,
    int? height,
    required String mediaType,
    String? phash,
    DateTime? indexedAt,
    @Default(1) int clipVersion,
  }) = _PhotoAsset;

  factory PhotoAsset.fromJson(Map<String, dynamic> json) =>
      _$PhotoAssetFromJson(json);
}
