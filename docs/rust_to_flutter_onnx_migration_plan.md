# Rust-to-Flutter ONNX Migration Plan

## Summary

Create a backup branch preserving the current Rust/ORT techstack, then perform a narrow migration to Flutter ONNX inference only. The project remains at **Phase 3 — Indexing Service** after migration; no Phase 4/5/6 work is pulled in, and no feature improvements are bundled with the stack pivot.

## Phase 0: Backup And Baseline

- Create a backup branch before migration edits: `backup-rust-ort-techstack`.
- Preserve the exact current state on that branch with a checkpoint commit, including existing modified files and `.misc/ort_runtime_binary_install.sh`.
- Create the migration branch from that preserved checkpoint: `migration-flutter-onnx-inference`.
- Do not rewrite, reset, or discard current work; the backup branch is the rollback point for the Rust/ORT implementation.

## Phase 1: Sync Project State Docs

- Rename every legacy agent instruction file to `AGENTS.md`, including root, scoped feature/core/service docs, and the temporary Rust directory doc.
- Update all references to use `AGENTS.md` in root instructions, feature docs, and `.misc/SESSION_PLAYBOOK.md`.
- Update `.misc/SESSION_PLAYBOOK.md` so future prompts remain phase-aligned after migration:
  - Current state remains **Phase 3 — Indexing Service**.
  - Phase 1/2 history is marked as implemented under the old Rust stack, not re-run.
  - Future Phase 3/4/5 prompts refer to Flutter ONNX inference through `InferenceRepository`, not Rust bridge calls.
  - Do not add new phase scope or complete future phase work during migration.
- Update `docs/stack.md`, `docs/models.md`, `docs/pipeline.md`, and `docs/search.md` only where needed to replace Rust/FRB with Flutter ONNX while preserving existing behavior.

## Phase 2: Dependency And Platform Migration

- Remove `flutter_rust_bridge`, `rust_lib_ai_gallery`, and `flutter_rust_bridge.yaml`.
- Add `flutter_onnxruntime` as the inference runtime package.
- Keep existing ONNX assets under `assets/models/`; no TFLite conversion in this migration.
- Add only support packages needed for parity, such as Dart image preprocessing utilities.
- Apply required Android/iOS plugin setup, including ProGuard/iOS deployment/linkage changes if required by the ONNX plugin.

## Phase 3: Replace Rust Bridge Seam

- Preserve the public API of `InferenceRepository`: `initModels`, `embedImage`, `embedText`, `detectObjects`, `embedFace`, `classifyEmotion`, and `computePhash`.
- Replace internals with Flutter ONNX session loading and Dart preprocessing/postprocessing.
- Move FRB-generated `BBox`, `Detection`, and `EmotionResult` into Dart-owned project types.
- Update imports in services, repositories, and debug probe from `lib/rust/...` to the new Dart types.
- Keep callers unchanged where possible so Phase 3 indexing can continue from the same conceptual state.

## Phase 4: Implement Behavior Parity Only

- Reimplement existing Rust behavior in Dart: CLIP image/text embeddings, YOLO detection/NMS, face embedding, emotion classification, and pHash.
- Preserve documented tensor shapes, normalization constants, thresholds, label mappings, bbox normalization, and embedding dimensions.
- Keep the same error handling semantics: model init failure is fatal; single-image inference failure is logged and skipped.
- Do not optimize UI, redesign screens, change schema, add features, or alter pipeline behavior beyond what is required for the migration.

## Phase 5: Remove Rust Artifacts

- Delete `rust/`, `rust_builder/`, `lib/rust/`, generated FRB files, and Rust-specific build references.
- Remove Rust/FRB entries from pubspec, lockfiles, iOS pods, and native project metadata.
- Replace logger/category names only if required to remove Rust-specific naming; otherwise avoid cosmetic churn.
- Verify no active code imports `flutter_rust_bridge`, `rust_lib_ai_gallery`, or `lib/rust`.

## Phase 6: Verification And Handoff

- Run `flutter pub get`, iOS pod refresh, `flutter analyze`, and existing tests.
- Add only migration-safety tests needed to prove parity for preprocessing/postprocessing and repository seams.
- Confirm app still starts at the same project phase and Phase 3 indexing remains the current continuation point.
- Final handoff must explicitly state:
  - Backup branch name.
  - Migration branch name.
  - Current phase after migration.
  - Any remaining Phase 3 work from `.misc/SESSION_PLAYBOOK.md`.
  - Confirmation that Phase 4+ work was not implemented.

## Assumptions

- Target stack is Flutter + `flutter_onnxruntime` + existing ONNX assets.
- This is a migration-only task, not a product improvement pass.
- Current phase remains **Phase 3 — Indexing Service** unless explicitly changed.
- Backup branch preserves the current Rust/ORT techstack before migration edits begin.
