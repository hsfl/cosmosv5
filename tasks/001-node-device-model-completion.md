---
status: todo
created: 2026-09-26
updated: 2026-09-26
---

# Finish the old→new node/device structure migration, using VMMO as the first real case

## Summary

cosmosv5's node/device JSON schema (`physicsstruc`, `piecestruc`,
`devicestruc`, `pvstrgstruc`, `battstruc` in `agent/libraries/support/
jsondef.h`) and the physics that consumes it (`Physics::ElectricalPropagator`
in `agent/libraries/physics/physicsclass.cpp`) both look complete on
inspection: full solar-cell power summation, device power draw, battery
charge/discharge integration, `to_json`/`from_json` on every relevant
struct. What's missing is everything *around* that — a real, populated node
definition to exercise it, and confidence that the rest of the legacy
`.ini`-based node model (COSMOS Core's per-user `~/cosmos/nodes/<name>/
*.ini` tree) has actually been ported to the realm-JSON model
(`<realm>/nodes/<name>.json`, loaded via `json_setup_node()` /
`json_node_payload_load()`) rather than just scaffolded for the simple
cases (ground stations) that happen to have been tried so far.

VMMO, via `science-operations-support-tool`, is the first real downstream
consumer hitting this gap — see
`science-operations-support-tool/tasks/001-vmmo-device-model-data.md` for
the concrete symptom (Power/Storage displays always reading zero). Treat it
as the motivating test case, not the whole scope: the goal is general
node/device support, not a one-off fix for one spacecraft.

## Background — what's confirmed so far

- `physicsstruc`/`piecestruc`/`devicestruc`/`pvstrgstruc`/`battstruc` exist
  in cosmosv5's `jsondef.h` with `to_json`/`from_json` already implemented.
- `Physics::ElectricalPropagator::Propagate()` is a full, working port of
  the old `src/core` power/battery model (solar-triangle summation, device
  draw, battery charge/discharge) — not a stub.
- The realm-JSON node loader (`json_setup_node()` →
  `json_node_payload_load()`) works for simple nodes — e.g.
  `realms/lunar/nodes/Goldstone.json` is just `name`/`type`/`loc`.
- Nobody has exercised that loader with a *fully populated* node (real
  pieces/faces/triangles/`pvstrg`/`batt`/other devices). VMMO's own attempt
  at this (the legacy `.ini` tree) is itself empty apart from a stale count
  manifest, so there's currently no known-good full example anywhere in the
  tree to copy from.

## Work items

### Audit
- [ ] Confirm every struct/field the old `.ini` node format could express
      (structures, pieces, faces, triangles, vertices, ports, every device
      type — not just `pvstrg`/`batt`) has a cosmosv5 JSON equivalent with
      working `to_json`/`from_json`. `src/core`'s node-loading code
      (`json_setup_realm`, the old `.ini` readers in `jsonlib.cpp`) is the
      reference for what fields matter — don't assume cosmosv5's copy is
      authoritative without checking, the way SOST already had to verify
      via `.o.d` depfiles for other subsystems.
- [ ] Identify whether any old-model concept has *no* new-model equivalent
      yet (that's where "finish the migration" work actually lives, if
      anywhere) versus everything already existing but never being driven
      end-to-end with real data (which is what the evidence points to so
      far).
- [ ] Cross-check against the in-progress JSON-type generalization effort
      (events — see the SOST-side project memory on this). Device/piece
      structs may be in scope for that same generalization; don't duplicate
      or fight it — check in before building on the current schema if it
      looks like it's about to move.

### Build a known-good full example
- [ ] Hand-author (or generate) a real `realms/lunar/nodes/vmmo.json` with
      real VMMO structure/piece/device data — solar panels as `pvstrg` with
      `ecellbase`/`ecellslope`/`vcell`, at least one `batt`, and whatever
      other devices should count toward `powuse`. Source actual numbers
      from VMMO subsystem specs / `SOSS_Design_Specification.docx` where
      available; use clearly-marked placeholders otherwise — don't let
      placeholder numbers get mistaken for real ones later.
- [ ] Validate it loads cleanly via `json_setup_node()` and that
      `ElectricalPropagator` produces sane, orbit-varying Gen/Use/Battery
      numbers. SOST's Power widget is the easiest way to eyeball this live.
- [ ] Once validated, this becomes the reference example for hand-authoring
      any other node's device model, and a test fixture for DMT (see
      `data-management-tool/tasks/001-dmt-cosmosv5-migration.md`).

### Tooling gap
- [ ] There is currently no supported way to *author* one of these node
      JSON files by hand at any real scale (52 pieces / 46 devices, per the
      stale VMMO manifest) other than writing JSON directly. That's the
      actual reason the DMT rebuild (separate task, separate repo) matters
      here — it exists to close this gap generally, not just for VMMO.
- [ ] Confirm whether a "dump populated cosmosstruc node back to
      `<realm>/nodes/<name>.json`" function already exists somewhere
      (`json_setup_node()`'s save direction) or needs writing — DMT will
      need it either way.

## Open question

Is the legacy `~/cosmos/nodes/vmmo/*.ini` data (structure/pieces/devices)
recoverable from somewhere else — an older commit, a design export, HSFL's
original authoring source — or does it need to be re-derived from scratch
from VMMO's subsystem specs? Worth checking before spending effort
re-deriving geometry that may already exist somewhere.

## If this produces any GUI/inspection tooling

Unlikely at this layer (cosmosv5 has no GUI of its own), but if anything
with a window comes out of this work (e.g. a standalone validator), it
should follow SOST's Interstel-logo convention — load from disk via
`get_cosmosresources() + "/logo/interstel_logo.png"`, not baked into a
`.qrc`. This applies directly to the DMT rebuild instead; see
`data-management-tool/tasks/001-dmt-cosmosv5-migration.md`.

## Status log

- 2026-09-26: created.
