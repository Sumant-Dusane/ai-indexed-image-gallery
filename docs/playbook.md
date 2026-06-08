# docs/playbook.md — Delivery playbook

Phase roadmap for AI Gallery. The active phase remains declared in `AGENTS.md`.
Future phases are planning entries only: do not implement them until they become
active or the user explicitly requests the work.

---

## Phase checklist

Checks mean the phase is tracked in this playbook/spec set. They are not release
sign-off. Before claiming a phase is shipped, verify its spec file and current
code. Current known gap from Phase 5 review: clustering exists, but it still
needs automatic full-clustering after initial index completion and incremental
assignment wiring for newly indexed faces.

- [x] Phase 1 - App foundation
- [x] Phase 2 - Inference repository
- [x] Phase 3 - Indexing service
- [x] Phase 4 - Search
- [x] Phase 5 - Face clustering
- [x] Phase 6 - UI polish and onboarding
- [x] Phase 7 - Isolate-backed background indexing architecture
- [ ] Phase 8 - Local AI efficiency and accuracy program
- [ ] Phase 9 - Optional local LLM/query assistant experiment

---

## [x] Phase 1 - App foundation

Spec: `docs/skeleton.md`

- Flutter app shell, router, permissions, SQLite schema, and placeholder screens
- Gallery thumbnails load directly from `photo_manager`

## [x] Phase 2 - Inference repository

Spec: `docs/models.md`

- Bundled ONNX model loading
- Dart-owned preprocessing, postprocessing, and pHash
- `InferenceRepository` remains the only app-facing inference entry point

## [x] Phase 3 - Indexing service

Spec: `docs/pipeline.md`

- Photo library sync, indexing queue, deduplication, embeddings, detections, and faces
- Foreground progress plus iOS `BGProcessingTask` and Android `WorkManager` scheduling

## [x] Phase 4 - Search

Specs: `docs/search.md`, `docs/ui-spec.md`

- Rule-based query parsing, vector search, metadata filters, and search UI

## [x] Phase 5 - Face clustering

Specs: `docs/clustering.md`, `docs/ui-spec.md`

- DBSCAN face clustering, incremental assignment, naming, and People UI

## [x] Phase 6 - UI polish and onboarding

Spec: `docs/ui-spec.md`

- Photos-style gallery polish, onboarding, indexing progress, and storage messaging

## [x] Phase 7 - Isolate-backed background indexing architecture

Status: proposed future phase

Specs to update when this phase starts: `docs/pipeline.md`, `docs/models.md`,
`docs/stack.md` only if the implementation requires a new package.

### Goal

Keep search indexing responsive without competing with interactive gallery use.
OS background execution and Dart isolate execution must work together:

- iOS `BGProcessingTask` and Android `WorkManager` decide when deferred work may run.
- A bounded Dart isolate pool keeps CPU-heavy preprocessing and postprocessing off
  the UI isolate during both foreground and OS-scheduled indexing.

### Current gap

`IndexingService` processes four assets concurrently with `Future.wait`, but
async concurrency is not isolate separation. Full-resolution file reads, image
decode, pixel conversion, and parts of inference orchestration can still compete
with UI rendering.

### Target architecture

1. Keep photo-library access on the main Flutter isolate where platform-channel
   plugin constraints require it.
2. Materialise one image at a time per worker budget, then transfer bytes with
   `TransferableTypedData`.
3. Run decode, resize, RGB conversion, tensor preparation, and pure-Dart
   postprocessing in a bounded isolate pool.
4. Define an explicit inference-isolate strategy after validating whether
   `flutter_onnxruntime` sessions can be created and safely retained per worker.
   Do not transfer ONNX session objects between isolates.
5. Keep SQLite ownership explicit. Prefer one DB writer on the service isolate
   receiving structured results from workers; do not share SQLite connection
   objects across isolates.
6. Preserve foreground interactive pausing: stop dequeuing new work while photo
   detail is open, allow the active item to settle, and resume afterward.
7. Continue unfinished work through iOS `BGProcessingTask` and Android
   `WorkManager`; do not assume either OS will run tasks immediately.

### Investigation checklist

- Benchmark one-, two-, and four-worker configurations on physical iOS and Android devices.
- Measure UI frame times, peak memory, thermal state, battery impact, and photos indexed per minute.
- Verify ONNX Runtime worker-session behavior on both platforms before selecting
  the final inference topology.
- Verify that platform-channel photo loading remains stable when invoked during
  OS background execution.
- Verify cancellation and app lifecycle handling: foreground, background,
  termination, task expiration, and resume.

### Acceptance criteria

- No full-resolution image decode, RGB conversion loop, or tensor preparation
  runs on the UI isolate where isolate execution is supported.
- Gallery scrolling and photo-detail navigation remain smooth while foreground
  indexing is active.
- Indexing resumes after interactive pauses and after app relaunch without
  duplicate DB rows or lost queue progress.
- iOS and Android background jobs continue indexing within platform limits and
  complete cleanly on expiration.
- Worker concurrency is bounded by measured memory and thermal limits, not only
  theoretical throughput.
- Single-image failures are logged and skipped without stopping the queue.

### Out of scope

- Video frame extraction. Keep the deferred video-handling plan separate.
- Network services, analytics, cloud queues, or remote model execution.

---

## Phase 8 - Local AI efficiency and accuracy program

Status: proposed future phase. Goal is better private search quality with less
battery, heat, latency, and storage. Keep zero network calls. Keep ONNX and
`InferenceRepository` unless `docs/stack.md` is explicitly overridden.

Research inputs checked June 2026:
- MobileCLIP / MobileCLIP2: Apple reports MobileCLIP as runtime-optimized for
  mobile and MobileCLIP2 as 3-15 ms, 50-150M parameter image-text models with
  improved zero-shot accuracy: https://machinelearning.apple.com/research/mobileclip
  and https://arxiv.org/abs/2508.20691
- SigLIP 2: multilingual vision-language encoder family; better image-text
  retrieval/localization than SigLIP, sizes from 86M to 1B:
  https://arxiv.org/abs/2502.14786
- YOLOv10: NMS-free real-time detector; useful because postprocess latency and
  duplicate suppression complexity matter on mobile:
  https://arxiv.org/abs/2405.14458
- EdgeFace: 1.77M parameter face-recognition model with strong edge-device
  accuracy claims: https://arxiv.org/abs/2307.01838
- PP-OCRv5: mobile OCR has much better detection/recognition metrics than
  PP-OCRv4, but OCR should be gated because OCR is still expensive:
  https://www.paddleocr.ai/main/en/version3.x/algorithm/PP-OCRv5/PP-OCRv5.html
- Florence-2: compact prompt-driven vision model for captioning, detection,
  grounding, segmentation; too broad for default full-library indexing:
  https://arxiv.org/abs/2311.06242
- SmolVLM: 256M/500M/2.2B compact VLM family; useful for on-demand captions or
  explanations, not for every photo during baseline indexing:
  https://arxiv.org/abs/2504.05299
- Matryoshka Representation Learning: nested embeddings can support shorter
  retrieval vectors with up to 14x reported smaller/faster retrieval in the
  original paper: https://proceedings.neurips.cc/paper_files/paper/2022/hash/c32319f4868da7613d78af9993100e42-Abstract-Conference.html
- ONNX Runtime: use static quantization for CNN-style models, dynamic for
  transformers when needed; NNAPI/CoreML EPs exist but must be profiled per
  model/device:
  https://onnxruntime.ai/docs/performance/model-optimizations/quantization.html
  https://onnxruntime.ai/docs/execution-providers/NNAPI-ExecutionProvider.html
  https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html

Main direction:
- Do not chase a bigger model first. Fix the pipeline math, scheduling, storage,
  and evaluation. Small model + calibration usually beats large model + no gates.
- Measure quality as retrieval quality, not benchmark vanity. The app cares
  about "can I find my beach birthday photo", not ImageNet alone.
- Every model candidate must ship with: license, model size, ONNX opset, input
  shape, output shape, preprocessing constants, quantization, calibration set,
  expected latency on one iPhone and one Android, memory peak, recall@k delta,
  battery/thermal notes, and migration plan.
- Add a local eval harness before swapping models. No model replacement without
  a 200-1000 photo private fixture and query set.

Local eval harness:
- Build `tools/eval/` only when this phase starts. It should run offline against
  a local fixture copied from device exports or synthetic fixtures.
- Minimum metrics:
  - image-text retrieval: recall@1/5/10/50, mAP, median rank.
  - metadata filters: filter precision/recall after query parsing.
  - object labels: precision/recall per label, person false-negative rate.
  - face clusters: pairwise precision/recall, cluster purity, unknown/noise rate.
  - energy: images/min, peak RSS, avg CPU, thermal state changes, battery % per
    1000 photos.
- Use A/B reports: current model vs candidate. Keep the same query set, same
  SQLite, same device, same battery/thermal starting point.
- Reject a candidate if recall@10 improves less than 2 percentage points but
  latency/storage/heat worsens materially. Accept a candidate if it improves
  visible search failures even when benchmark improvement is small.

Retrieval math:
- Store L2-normalized embeddings. Cosine distance is `1 - dot(a, b)`. With
  normalized vectors, dot product is cosine similarity. That keeps ranking cheap.
- Quantization drift bound for normalized vectors: if quantized embeddings are
  `x' = x + ex`, `y' = y + ey`, then
  `abs(dot(x, y) - dot(x', y')) <= norm(ex) + norm(ey) + norm(ex) * norm(ey)`.
  Measure `norm(error)` on the calibration set; do not guess.
- Two-stage search:
  - coarse: scan low dimension or quantized vectors for top K.
  - rerank: exact full float vector for K candidates.
  - cost changes from `O(N * d_full)` to `O(N * d_low + K * d_full)`.
  - example: N=50k, d_full=512, d_low=128, K=500 gives about 50k*128 +
    500*512 = 6.656M multiply-adds instead of 25.6M, roughly 3.8x less vector
    math before SQLite overhead.
- If a future MobileCLIP/SigLIP candidate is not MRL-trained, do not blindly
  truncate vectors and assume quality. Test prefix truncation at 64/128/256/512.
- Cache text query embeddings by normalized query string. Query embedding should
  be near-free after first run.

Indexing gates:
- Cheap gates first: permission, storage, pHash duplicate, media type, dimension,
  EXIF date, existing indexed version.
- Do not run OCR/captioning/VLM on every photo by default. Gate by:
  - screenshot/document likelihood,
  - presence of large text-like regions,
  - user query requiring text,
  - charging + idle + thermal OK,
  - debug playground.
- Keep expensive generated captions out of the default search path until they
  prove higher recall than CLIP+labels. Captions can hallucinate; embeddings and
  detector labels are more stable.
- Run face embedding only after person detection. If YOLO misses people often,
  first improve person detector or lower threshold; do not make FaceNet scan all
  images blindly.
- Use model sessions like scarce resources. Warm only the current stage, unload
  nonessential sessions under memory pressure, and serialize heavy VLM/OCR runs.

Model candidates to benchmark, not blindly add:
- Image-text embedding replacement:
  - MobileCLIP2 S0/S1/S2/B: best fit for local photo search if ONNX export and
    tokenizer path are stable. Primary candidate to replace current MobileCLIP.
  - SigLIP 2 B/patch16: better multilingual and semantic quality; likely heavier
    than MobileCLIP. Candidate if users search in multiple languages or MobileCLIP
    misses abstract concepts.
  - Keep current MobileCLIP if candidate gains are small; the cost of reindexing
    every photo is real.
- Object detector:
  - YOLO11n/YOLO11s: practical Ultralytics path, ONNX export likely smooth.
  - YOLOv10n/s: interesting because NMS-free postprocess may reduce latency.
  - RT-DETRv2/R18: benchmark only if transformer detector export is stable; may
    be less mobile-friendly despite good accuracy.
  - Do not add open-vocabulary detection to full indexing yet.
- Face recognition:
  - EdgeFace: very attractive for mobile due to tiny parameter count.
  - InsightFace buffalo_s/sc: practical ONNX packs; check license and mobile
    latency. buffalo_l is probably too large for default mobile.
  - AdaFace IR18: accuracy candidate for hard faces; likely heavier than
    MobileFaceNet/EdgeFace.
  - Any face model swap requires reclustering migration and threshold retuning.
- OCR:
  - PP-OCRv5 mobile det+rec for screenshots/documents. It may improve text
    search a lot, but run only on gated subsets.
  - PP-OCRv4 mobile can remain a fallback if v5 latency is bad on phones.
  - Do not use a general VLM as primary OCR. Specialized OCR is smaller and more
    predictable.
- Caption/VLM:
  - Florence-2-base: useful as an on-demand "describe this photo" or enrichment
    model when charging. It covers captioning, detection, grounding, and OCR-like
    tasks, but that broadness is exactly why it should not be default indexing.
  - SmolVLM-256M/500M: candidate for optional on-device explanations or caption
    generation after the app already works with embeddings.
  - Moondream2: candidate for tiny VQA/caption playground, not baseline index.
- Non-neural helpers:
  - Blur score via variance of Laplacian or gradient energy.
  - Aesthetic/quality score via tiny MobileNet/NIMA-style model if "best photos"
    becomes a feature.
  - Color histogram and dominant colors for queries like "red dress" where CLIP
    can be fuzzy. This is cheap and explainable.

Quantization/optimization rules:
- Always benchmark FP32/FP16/INT8 on the same photo set. Quantization is accepted
  only if recall/search quality stays within budget.
- CNN detectors/face models: try static INT8 with calibration photos first.
- Transformer embedding models: try FP16/CoreML/NNAPI first, then dynamic/static
  quantization depending on operator support and accuracy.
- Prefer static input shapes. Dynamic shapes often cost performance on mobile
  accelerators.
- For iOS, benchmark CoreML EP with `MLComputeUnits=ALL` and cache enabled.
- For Android, benchmark NNAPI with and without FP16. NNAPI can be faster or
  slower depending on vendor drivers; never assume.
- Store model version in DB-visible metadata before changing embeddings. Existing
  `clip_version` is the reindex lever for image embeddings; if more embedding
  families are added, update schema first.

Accuracy strategy:
- Use ensemble at query time only when it is cheap: CLIP vector + labels + date +
  faces. Do not run multiple embedding models for every photo.
- Use query expansion without LLM first: synonyms, object label vocabulary,
  person names, date grammar, location tokens when available.
- Use hard-negative evaluation: queries that currently fail should be saved as
  local eval cases. This is more valuable than random benchmark wins.
- For face clusters, tune epsilon on the local fixture. DBSCAN epsilon 0.4 is the
  current fixed spec; only change it with a docs/spec update and measured gains.
- For labels, track per-class false positives. Bad labels are worse than missing
  labels because they poison search trust.
- Make index work interruptible. User-visible smoothness outranks background
  throughput.

Phase 8 acceptance criteria:
- A local eval harness exists and runs offline.
- At least current MobileCLIP vs one candidate is benchmarked on real device.
- At least current YOLO vs one detector candidate is benchmarked on real device.
- Quantized and non-quantized variants are compared with recall/latency/memory.
- Search quality improvement is demonstrated by saved failing queries.
- No network calls, no analytics, no remote model execution.
- Any schema/provider/model changes are reflected in the relevant spec docs first.

---

## Phase 9 - Optional local LLM/query assistant experiment

Status: proposed future phase only. Do not implement unless `docs/stack.md` is
explicitly overridden. Current locked stack says rule-based query parsing over
on-device LLM because it is faster, smaller, predictable, and sufficient.

Short answer: do not add an LLM to the core indexing/search path now.

Why not now:
- An LLM does not make embeddings better. It can rewrite queries, explain
  results, or map vague language to filters, but it does not replace CLIP/YOLO/
  face/OCR.
- A local LLM adds memory pressure, tokenizer/runtime complexity, startup cost,
  safety behavior, and another model update path.
- The current app promise is private photo search. The highest ROI is better
  embeddings, better gates, OCR for screenshots, and a real eval harness.
- The locked stack currently has no LLM runtime. Autoregressive generation through
  plain ONNX in Flutter may be possible but is not the same as having a supported
  mobile LLM runtime with KV cache, sampling, quantized weights, and tokenizer.

Where an LLM could help later:
- Query rewrite: "photos from last Diwali with Rahul near beach" -> clean query
  plus person/date/object filters.
- Ambiguous intent: "best ones from the trip" -> use dates, location, favorites,
  blur/aesthetic score, faces.
- Local synonym generation: build a private alias map for people/events/places.
- Explain why a result matched: "matched beach via embedding and Rahul via face".
- Natural-language batch actions only if the app later adds editing/album tools.

Candidate text-only local LLMs to benchmark if Phase 9 starts:
- Qwen2.5-0.5B/1.5B: small, Apache 2.0 for these sizes, useful for rewrite and
  structured JSON extraction. Source: https://qwenlm.github.io/blog/qwen2.5-llm/
- Llama 3.2 1B/3B: designed for edge/mobile text tasks; license and runtime need
  review. Source: https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/
- Gemma 3n: mobile-first, multimodal, low-footprint architecture; likely more
  than needed for simple query rewrite, but useful if future app wants image/audio
  understanding. Source: https://developers.googleblog.com/en/introducing-gemma-3n/
- Phi-4-mini 3.8B: strong reasoning but probably too heavy for this app's default
  path. Source: https://arxiv.org/abs/2503.01743

Phase 9 hard gates:
- Must be opt-in or debug first.
- Must run only on submitted text queries, never across the whole photo library.
- Must return typed JSON matching existing query intent fields; no direct SQL.
- Must timeout fast and fall back to rule-based parser.
- Must not add network calls.
- Must not change search results unless A/B eval shows improvement.
- Requires stack spec update for runtime, tokenizer, model format, quantization,
  memory budget, and safety/fallback behavior.
