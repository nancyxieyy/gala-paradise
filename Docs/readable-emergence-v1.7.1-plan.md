# 1.7.1 Readable Emergence — frozen implementation and evaluation plan

Written before implementation or new experiment runs. Baseline commit: 1b0ea3c (1.7.0). No applicable AGENTS.md found. Reviewed the design draft, World/bridges, simulation inputs and evidence, native renderers, gameplay/life/interaction/save code and release scripts.

## Current implementation

1. Migration preference is nestability × .6 + food × (.4 + hunger) − disturbance × 1.4 − chemical × 2 − pressure × .4 + safety × .2 + .08 for locationMemory.
2. Select the maximum across ordered habitats, first on ties. Require destination != current and advantage > .15; flee migrates immediately, otherwise a 2/40 probability per decision.
3. Decision reevaluation is every 2 active seconds; no offline advancement. Native movement is interpolated at 30 Hz.
4. Existing cooldown is 20 seconds after migration, also reused for 120-second reproduction cooldown. Location memory is overwritten on arrival. No explicit reversal history, commitment or decaying inertia.
5. Chemical currently has a 1.15-second spray effect but no persistent residue. Migration updates logical location immediately; native appearances use random paths and an old origin, without departure/arrival continuity. Nests show a fixed bottom-right text button only after exposure. Eggs are static art; new projected entities default to (12,24), and hatching loses spatial continuity.
6. Hidden causality: residue duration, gathering before nests, source of new juveniles, and where an individual moved. These are projection gaps, not missing ecology rules.

## Minimal changes

World: migration decision helper plus saved last migration/source and parent-egg metadata. Preserve director, all utility scores, chemistry, nest/egg lifecycle and PRNG algorithm. Bridges/native overlays: stable anonymous habitat anchors, low-frequency residue/crumb snapshots, real departure/transit/arrival, egg appearance and source-continuous hatching. Existing input/save boundaries gain isolated blind sessions with whitelisted buffered logs. Harness gains metrics and H/I inputs. Add focused tests and update version/docs/packages.

Explicitly unchanged: animals/art style, Life relationship rules, notes/adoption mechanics, achievements, currency/tool prices, folder privacy contract, renderer architecture, director, food/chemical/egg rates and capacity. No fake causal events, tutorials, rule-number UI, AI or content expansion.

## Frozen experiment

Seeds: **7, 19, 42, 73, 101**. Run F and H for every seed in control and treatment; C for all seeds as a guardrail. A–I regression and full Swift/C# world/events/samples/PRNG parity. Never select seeds based on results.

Control: exact 1.7.0 migration conditional and random-call ordering. Measurement/lineage metadata must not consume RNG. Verify seed-42 F reproduces 251 migrations / 20 deaths.

One treatment candidate only: minimum advantage **.30**, plus **.12** current-destination bonus decaying linearly over **90 seconds** since a true migration; commitment **30 seconds**. Retain the existing cooldown outside emergencies. Strong stimulus = chemical > .6, fear + threat > .9, disturbance > .85, or pressure > 2. Strong stimulus bypasses cooldown/commitment/bonus, still requires a better destination by > .15 and normal flee/probability selection. No long absolute lock. No parameter search this round; report a failed candidate honestly.

Reversal: for each entity, consecutive migration A→B followed by B→A within **120 active seconds**, inclusive. Count the second leg once. Rate = reversals / migrations (0 if no migrations). Includes justified emergency reversals; no exclusions after observing data. Store last migration source/time, initially empty / -1 (unknown), without fabricated history.

Primary: F pooled reversal rate at least 40% lower, and lower in at least 3/5 seeds (zero→zero is neutral). Also report each seed, H and pooled values. A missed target is FAIL for primary; do not relabel it PASS because total migrations declined. Overall can be PARTIAL when engineering and guardrails hold but primary fails.

Guardrails: every H seed has migration from shocked habitat within 120 seconds of shock; F/C treatment visits at least two habitats in at least 4/5 seeds, forms a nest in at least 4/5, and pooled final live population >= 50% control. C must retain post-shock migration, redistribution, nest formation and later recolonization in at least one seed. No-egg and empty-world controls remain empty. Report all population distributions, births (including egg entities), deaths, nests, extinction and recolonization. Chemical-associated migration = departure from habitat with chemical > .4 at that tick (association, not proof of sole cause). Recolonization = live occupancy >0 after a previously occupied habitat reaches zero, counted per habitat transition; measured every tick.

H: two equal habitats, initial crowding, same small food additions alternating every 60 seconds, strong chemical shock in A at 900 seconds; 1800 seconds total. I: the existing D recovery initial conditions, every-tick developmental timeline with adult-clear/egg/hatch/juvenile/migration/nest evidence. No new ecology rule to make either scenario pass.

## Projection and blind validation

Cues read current habitat/egg state; migration travel reads real events. Empty shells are temporary render artifacts of actual hatch events, never ecological entities. Snapshot updates stay on 2-second ticks. No World writes from drawing. Session-only routes do not replay historical events after load. Pause/focus suppress presentation and do not accumulate ecological catch-up.

Each --blind-playtest invocation uses a new UUID directory under app support / BlindPlaytests; never opens formal save. Normal UI, no seed/debug/world numbers. Buffered JSONL contains only anonymous action IDs, entity IDs, anonymous habitat aliases, timestamps and whitelisted world transitions; no text, note, name, clipboard, path, folder title or keys. Observer records their own markers separately. Human status remains READY_FOR_HUMAN_VALIDATION until actual people are tested.

Validation: full model tests, old missing-field saves, emergency/commitment/reversal/PRNG tests; Mac native integration including projection and isolation; Windows model/build/publish (native GUI not validated); current Apple Silicon 30-second paused/hidden and active benchmarks against historical 0.76%/101.7 MiB and 3.03%/118.3 MiB. Report failures, limitations and all actual commands.
