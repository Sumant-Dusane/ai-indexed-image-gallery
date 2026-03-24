# CLAUDE.md — Services layer

Before working here, read the spec doc for the service you are modifying.

---

## Files owned

```
lib/services/
  indexing_service.dart      ← Phase 3, spec: docs/pipeline.md
  query_service.dart         ← Phase 4, spec: docs/search.md
  face_cluster_service.dart  ← Phase 5, spec: docs/clustering.md
```

## Rules

- Services contain business logic only — no UI, no widgets, no Scaffold
- Services access DB via the database provider from `lib/core/providers/database_provider.dart`
- Services call Rust via `lib/core/repositories/inference_repository.dart` — never call bridge directly
- Services expose state via providers defined in `lib/core/providers/`
- All heavy computation must run in background isolates (`compute()` or `Isolate.run()`)
- Each service has exactly one corresponding spec doc — implement what the spec says, nothing more

## Do not implement here

- UI widgets or screens → `lib/features/`
- Data models → `lib/core/models/`
- Provider declarations → `lib/core/providers/`
- Rust bridge calls → `lib/core/repositories/inference_repository.dart`
- Database schema or migrations → `lib/core/db/`
