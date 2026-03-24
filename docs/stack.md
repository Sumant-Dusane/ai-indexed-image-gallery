# docs/stack.md — Tech stack (locked)

Do not substitute any of these. Decisions are final.

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
| `sqflite` | ^2.3.0 | SQLite access |
| `sqlite_vec` | latest | sqlite-vec extension (vector search) |
| `flutter_rust_bridge` | v2 | Dart ↔ Rust FFI bridge |
| `path_provider` | ^2.1.0 | DB file path |
| `shared_preferences` | ^2.2.0 | Onboarding flag, simple key-value persistence |

## Rust

| Crate | Version | Purpose |
|---|---|---|
| `flutter_rust_bridge` | v2 | Bridge codegen |
| `ort` | ^2.0 | ONNX Runtime bindings |
| `image` | ^0.25 | Image resizing + pixel manipulation |
| `rayon` | ^1.10 | Parallel batch inference |
| `once_cell` | ^1.19 | Lazy static ONNX sessions (`OnceLock`) |
| `ndarray` | ^0.16 | Tensor construction |

## Storage

- Single SQLite file at `getApplicationDocumentsDirectory()/gallery.db`
- `sqlite_vec` Dart package handles extension loading — call its init before any vec0 table access
- All vector search via `vec_distance_cosine()` SQL function
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
- **Rust over Dart for inference**: no GC pauses during embedding, rayon parallelism, deterministic memory
- **sqlite-vec over Chroma/Weaviate**: no extra binary, hybrid SQL+vector in one query
- **DBSCAN over k-means**: no need to specify cluster count, handles noise faces naturally
- **Rule-based query parsing over on-device LLM**: faster, smaller, predictable, sufficient
- **Riverpod over bloc**: less boilerplate, better for async streams, fits this architecture
- **riverpod_generator over classic Riverpod**: type-safe, less manual wiring, compile-time checks
- **freezed over plain classes**: generated equality, copyWith, pattern matching, no boilerplate
