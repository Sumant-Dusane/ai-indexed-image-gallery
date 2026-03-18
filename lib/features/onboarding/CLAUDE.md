# CLAUDE.md — Onboarding feature

Read before any work in lib/features/onboarding/.
UI spec: @docs/ui-spec.md (OnboardingScreen section)

---

## Files owned

```
lib/features/onboarding/
  onboarding_screen.dart         ← first-launch only, progress display
```

## Show condition

Check `SharedPreferences` key `onboarding_complete` (bool, default false).
If false → show OnboardingScreen as initial route.
If true → go directly to GalleryScreen.

On "Skip" tap OR when `indexingState.indexed == indexingState.total`:
  set `onboarding_complete = true` in SharedPreferences
  navigate to GalleryScreen (replace, not push)

## Providers consumed

- `indexingProvider` → IndexingState (total, indexed, isRunning)
  Use to drive progress bar and counter text.

## Phase checkmarks

Track completion of each phase locally in this widget's state:
- "Scenes" checks off when first CLIP embedding is written (indexed >= 1)
- "Objects" checks off when first detection row is written
- "People" checks off when first face row is written

Query these counts from DB once per second while screen is visible.
