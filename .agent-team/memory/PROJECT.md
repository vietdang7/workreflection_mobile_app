# Project Memory

## What this project is
WorkReflection is a bilingual Flutter mobile app for workplace reflection, Career Memory, Self-Check and Premium Deep Reading.

## Stack & commands
Flutter 3.x / Dart 3.11, Riverpod, GoRouter and Supabase. Integration commands, run serially: `flutter pub get`; `dart format --output=none --set-exit-if-changed lib test`; `flutter analyze`; `flutter test`.

## Architecture & key modules
- `lib/core/logic/`: framework-free counting, picker, Career Memory and Deep Reading rules.
- `lib/core/data/wr_canonical_catalog.dart` plus bundled `assets/seed/wr_situations.json` and `wr_stories.json`: authoritative v2 catalog; 72 real situations plus custom option. Canonical content overrides stale remote rows; unknown history remains readable and unclassified.
- `lib/features/wr/`: providers and reflection, Journey, Self-Check and Deep Reading screens.
- Supabase migration `20260914000000_wr_situations_v2.sql`: retirement/upsert, unapplied in this mission. Historical migrations remain immutable.

## Conventions
Run upstream GitNexus impact before existing-symbol edits, surface HIGH/CRITICAL risk, inspect direct callers and run change detection after modifications. CLI/MCP transport fallback is available if tools are not exposed. Preserve embeddings on reindex.
Measure by explicit pillar; filter picker by mood; separate valence. Snapshot uses classified reflections, dominance/gap uses challenges. Legacy dimension metadata never supplies v2 classification. Custom/unknown history never inflates counts. Preserve remote history and existing AI consent/safety behavior.

## Current state & evolution
V2 library, unseen-first picker, five-rung Deep Reading, compact pending footer and reflection resume fixes are integrated. Persisted demo overrides are disabled at entitlement/chat boundaries. Recent history normalizes malformed whole fields and list members eagerly. Future AI note-reader is not implemented.
Source conflicts are settled: JS has 24 positives despite Word heading 23; preserve literal C1-10 title. R4 includes zero positive share; R5 evenly distributed fixtures use mixed valence. Manual device/account restart, remote migration, StoreKit/store and opt-in screenshots remain unverified. No commit or deploy performed.
