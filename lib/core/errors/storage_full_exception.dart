/// Thrown when a photo library operation fails because the device has no
/// free storage space. Wraps the underlying [PlatformException] from
/// [photo_manager]'s [AssetEntity.file] call.
///
/// Detection: [PhotoRepository] catches [PlatformException] with
/// NSCocoaErrorDomain code 640 (NSFileWriteOutOfSpaceError) or a message
/// containing "out of space" / "no space left", and re-throws as this type.
class StorageFullException implements Exception {
  final String message;

  const StorageFullException(this.message);

  @override
  String toString() => 'StorageFullException: $message';
}
