# docs/stack.md — Tech stack (locked)

Do not substitute any of these. Decisions are final.

## Platforms

iOS and Android only. No web, macOS, Linux, or Windows support.

## Flutter / Dart

| Package | Version | Purpose |
|---|---|---|
| `flutter` | 3.x | UI framework |
| `flutter_riverpod` | ^2.5.0 | State management — only this |
| `riverpod_generator` | ^2.4.0 | Code-gen for `@riverpod` providers |
| `riverpod_annotation` | ^2.3.0 | `@riverpod` / `@Riverpod` annotations |
| `freezed` | ^2.5.0 | Immutable data class codegen (dev dependency) |
| `freezed_annotation` | ^2.4.0 | `@freezed` annotation |
| `json_annotation` | ^4.9.0 | JSON serialization annotations (used by freezed) |
| `json_serializable` | ^6.8.0 | JSON codegen (dev dependency) |
| `build_runner` | ^2.4.0 | Code generation runner (dev dependency) |
| `go_router` | ^14.0.0 | Navigation |
| `photo_manager` | ^3.0.0 | Photo library access (iOS + Android) |
| `workmanager` | ^0.5.0 | Background tasks (Android WorkManager + iOS BGTask) |
| `sqlite3` | ^3.2.0 | SQLite access (lower-level FFI binding required by sqlite_vector) |
| `sqlite_vector` | ^0.9.93 | Vector similarity search extension (replaces sqlite_vec) |
| `flutter_onnxruntime` | ^1.7.1 | ONNX Runtime session loading and inference from Flutter |
| `image` | ^4.7.2 | Dart image resize/crop/letterbox/grayscale preprocessing |
| `dart_sentencepiece_tokenizer` | ^1.3.2 | HuggingFace tokenizer JSON loading for CLIP text tokens |
| `path_provider` | ^2.1.0 | DB file path |
| `shared_preferences` | ^2.2.0 | Onboarding flag, simple key-value persistence |

## Inference

- ONNX model files stay bundled in `assets/models/`.
- `lib/core/repositories/inference_repository.dart` is the single app-facing inference seam.
- Dart owns preprocessing, postprocessing, pHash, and tensor packing.
- `flutter_onnxruntime` owns native ONNX session execution.
- No Rust crate, Rust bridge, generated bridge code, or local Rust plugin is part of the active stack.

## Storage

- Single SQLite file at `getApplicationDocumentsDirectory()/gallery.db`
- Open DB via `sqlite3` package; call `sqlite3.loadSqliteVectorExtension()` immediately after open
- Call `vector_init(table, column, options)` for each embedding table before first use
- Vector search via `vector_full_scan()` (exact) or `vector_quantize_scan()` (ANN) table-valued functions
- No separate vector DB process

## Code generation

After creating or modifying `@freezed` models or `@riverpod` providers:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Future additions (not in current scope)

- `ffmpeg_kit_flutter` — video frame extraction. Planned for a future phase. Do not add yet.

## Why these choices (do not revisit)

- **ONNX over TFLite**: single model format, INT8 support, same file on iOS + Android
- **Flutter ONNX Runtime over a local native bridge**: one Flutter-managed inference seam, no generated bridge layer, no local native plugin
- **sqlite-vec over Chroma/Weaviate**: no extra binary, hybrid SQL+vector in one query
- **DBSCAN over k-means**: no need to specify cluster count, handles noise faces naturally
- **Rule-based query parsing over on-device LLM**: faster, smaller, predictable, sufficient
- **Riverpod over bloc**: less boilerplate, better for async streams, fits this architecture
- **riverpod_generator over classic Riverpod**: type-safe, less manual wiring, compile-time checks
- **freezed over plain classes**: generated equality, copyWith, pattern matching, no boilerplate
