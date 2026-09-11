# Emergent desktop world V0 — implementation plan

## Current architecture

Inspected README, the full design draft, all Game / Progression / Habitat / Life / LifeActions / LifeUI / DirectInteraction files, App.swift, Desktop.cs, Roaming, ExplorerWatcher, model tests, native integration tests, build scripts and save decoding. No applicable AGENTS.md found.

Mac GameState owns residents, currency/progression and optional Life; Habitat is a separate JSON save. App.swift currently owns ecology timers and scene scheduling. Windows SaveState owns those same domains including Habitat; Game.cs owns both model and scheduling. These are parallel implementations, not a shared runtime. Native AppKit and WinForms layers render vector artwork and route mouse input. Mac AX and Windows Shell COM poll foreground folder identity/bounds once per second; Habitat hashes identity, stores no contents.

Fixed triggers currently include feed-to-spawn; folder-risk-to-count; permanent poisoned-folder corpses; 55-second egg hatching; periodic egg generation; an empty-world survivor after 24 seconds; gold every 45–90 seconds; mouse at 180 / cat at 600 played seconds; trace every 60 seconds generating a gold animal. Life exposes trust thresholds in UI. Save migrations preserve old XP tools, names, protection, notes and earned cards.

## What can be reused

Native overlays, cartoon art, click/hover/menu routing, tool effects, movement interpolation, screen-edge geometry, folder identity hashing, shell economy, one-time achievement accounting, partner protection, focus, explicit note storage and offline adoption. Keep Resident as the renderer/interaction compatibility projection and Life as the authoritative relationship/document ledger.

## What needs refactoring

Add authoritative World state for ecological identity/stage, habitat membership, needs, memory, intent, nests, chemical exposure, lifecycle and visitor pressure. Native events enter typed signals. The world, not UI callbacks, decides ecological births, movements and visitors. Remove old ecology schedulers rather than run two simulators. Keep display budget/short visits as presentation constraints. Replace trace spawning with revealing an existing exposed nest.

## Risks

Two languages can drift: matching deterministic PRNG, iteration order, fixed tick and cross-platform scenario comparisons required. Projection reconciliation must not resurrect killed/vacuumed animals or destroy protected identities. Old wall-clock ages must not cause offline mass hatching; import as conservative stages with fresh simulation age. Focus/quiet must not accumulate catch-up work. Extinction is possible and must not secretly invoke the old survivor script. Population, habitat and log sizes need bounds. Geometry is presentation-only; deterministic ecology does not promise identical pixel paths across platforms. Chemical deaths must settle rewards exactly once, only for player-applied exposure. Missing new save fields use defaults, without invented past events or cards.

## Proposed implementation

1. Foundation-only Swift World and UI-independent C# World with explicit schema, saved seed/PRNG state, 2-second fixed simulation step and action signals. Ten bounded rules: disturbance, habitat preference, nest formation, lifecycle, chemical, pressure, memory, food, utility selection, ecology-conditioned visitors. Lightweight director returns scalar pressure/rarity/tension only.
2. Import legacy residents/hashed habitat metadata once. World is ecological source; adapters synchronize explicit game actions and relationships, then project world results to existing residents/overlays. Low-frequency simulation, bounded recent log, optional full developer event sink, coalesced dirty saves.
3. Feed changes food; folder visits change disturbance; spray changes localized residue. Protect partners/safety areas; preserve all other controls. Remove numerical relationship countdown language and fixed discovery timers.
4. Headless scenarios A–E plus long runs, JSON action input/output, deterministic replay/save-resume, migration/protection/focus checks. Measure headless execution and isolated native idle resources.
5. Write results from actual logs, distinguish direct rules from interaction chains, document failed hypotheses and limits. Build both platforms, run Mac integration and Windows model checks, update README. No new pages, animals or achievements.
