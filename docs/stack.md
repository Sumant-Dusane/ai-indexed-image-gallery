# docs/stack.md — Tech stack (locked)

Do not substitute any of these. Decisions are final.

## Flutter / Dart

| Package | Version | Purpose |
|---|---|---|
| `flutter` | 3.x | UI framework |
| `riverpod` / `flutter_riverpod` | latest | State management — only this |
| `go_router` | latest | Navigation |
| `photo_manager` | latest | Photo library access (iOS + Android) |
| `workmanager` | latest | Background tasks (Android WorkManager + iOS BGTask) |
| `sqflite` | latest | SQLite access |
| `sqlite_vec` | latest | sqlite-vec extension (vector search) |
| `flutter_rust_bridge` | v2 | Dart ↔ Rust FFI bridge |
| `path_provider` | latest | DB file path |

## Rust

| Crate | Purpose |
|---|---|
| `flutter_rust_bridge` | Bridge codegen |
| `ort` | ONNX Runtime Mobile bindings |
| `image` | Image resizing + pixel manipulation |
| `rayon` | Parallel batch inference |
| `once_cell` | Lazy static ONNX sessions |
| `ndarray` | Tensor construction |

## Storage

- Single SQLite file at `getApplicationDocumentsDirectory()/gallery.db`
- `sqlite-vec` extension loaded at DB open time via `sqflite` custom function
- All vector search via `vec_distance_cosine()` SQL function
- No separate vector DB process

## Why these choices (do not revisit)

- **ONNX over TFLite**: single model format, INT8 support, same file on iOS + Android
- **Rust over Dart for inference**: no GC pauses during embedding, rayon parallelism, deterministic memory
- **sqlite-vec over Chroma/Weaviate**: no extra binary, hybrid SQL+vector in one query
- **DBSCAN over k-means**: no need to specify cluster count, handles noise faces naturally
- **Rule-based query parsing over on-device LLM**: faster, smaller, predictable, sufficient
- **Riverpod over bloc**: less boilerplate, better for async streams, fits this architecture
