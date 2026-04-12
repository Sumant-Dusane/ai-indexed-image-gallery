import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'blocking_error_provider.g.dart';

@Riverpod(keepAlive: true)
class BlockingErrorNotifier extends _$BlockingErrorNotifier {
  @override
  String? build() => null;

  void setError(String message) => state = message;

  void clearError() => state = null;
}
