# CLAUDE.md — Debug Probe feature

Debug-only. Controlled by `utils/constants.dart: kDebugProbeEnabled`.
Zero DB writes. Zero network calls.

---

## Purpose

Pick one image, run the full indexing pipeline via `ImageIndexingPipeline` with
capturing (no-op) repositories, and display all intermediate values on screen.

## Structure

```
lib/features/debug_probe/
  utils/constants.dart                         ← kDebugProbeEnabled flag
  domain/debug_probe_result.dart               ← DebugProbeResult, FaceDebugResult
  data/capturing_repositories.dart             ← 4 capturing subclasses (no-op writes)
  data/debug_probe_repository.dart             ← builds pipeline, runs it, assembles result
  presentation/debug_probe_controller.dart     ← @riverpod notifier (AsyncValue<DebugProbeResult>?)
  presentation/debug_probe_screen.dart         ← ConsumerStatefulWidget
  presentation/widgets/probe_section.dart      ← collapsible card section
  presentation/widgets/copy_value_row.dart     ← label + value + copy button
  presentation/widgets/vector_display.dart     ← float vector stats + preview
```

## Unification rule — do not clone pipeline logic

`DebugProbeRepository` builds a real `ImageIndexingPipeline` with capturing repos.
It does NOT duplicate the call sequence. If a new handler or model is added to the
main pipeline, the debug probe captures it automatically.

If a new repo type is added to a handler, add one more capturing subclass in
`capturing_repositories.dart` — that is the only change needed.

## Do not implement here

- Any DB schema or migrations
- Any modifications to existing handlers, services, or repositories
- Any network calls
