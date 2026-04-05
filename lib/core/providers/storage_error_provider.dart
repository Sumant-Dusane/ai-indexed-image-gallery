import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_error_provider.g.dart';

@Riverpod(keepAlive: true)
class StorageErrorNotifier extends _$StorageErrorNotifier {
  @override
  String? build() => null;

  void setError(String message) => state = message;

  void clearError() => state = null;
}
