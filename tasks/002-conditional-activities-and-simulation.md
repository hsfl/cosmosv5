---
status: in-progress
created: 2026-10-11
updated: 2026-10-12
---

# Conditional activities through the command queue, and simulating them

## Summary

Detector activities are driven by the command queue: conditional Events whose
condition is a COSMOS equation (e.g. elto > 50 and lat < -70 and sun > x) and
whose data is a standard request (`request_adcs point ...`,
`request_camera ...`). On the spacecraft those requests are nops until a
real handler overrides them. In the simulator the same queue is evaluated
against simulated time and the recognized requests are interpreted
in-process (`parse_commands()`), so one command file serves both.

Authoring (human units, one condition per row) is in DMT:
`data-management-tool/tasks/003-dmt-activity-conditions.md`.

## Background

- `Event` / `CommandQueue` (`agent/libraries/agent/`) already evaluate
  conditions with `json_equation()` against a `cosmosstruc`. Commands go
  to `agent->task_add()` (shell), requests to `agent->process_request()`.
- Conditions are **infix equations over Namespace 2.0 names**
  (`agent/libraries/support/equation.h`), in SI units and radians. For example,
  lat < -70° and h > 400 km is
  `node.loc.pos.geod.s.lat < -1.2217 and node.loc.pos.geod.s.h > 400000`.
  Targets can be named by index or by name: `target[3].elto`,
  `target[Shackleton crater].elto`. Namespace 1.0 names (`node_loc_...`) are no
  longer accepted in conditions, and old queue files are not migrated.
  A missing or non-numeric name makes the condition NAN, which counts as false.
- `Agent::add_request()` stores requests in a map by token, so registering
  the same token again replaces it. That is the override mechanism for the
  default nops.
- Requests have the form `request_<subsystem> <command> [args...]`. The first
  argument is always the command. Other arguments are TBD.
- "elevation" means `elto`: the spacecraft's elevation seen from a target,
  as used for SOST nodal awareness.
- The current detector/ADCS event generation is SOST nodal awareness,
  `tools/libraries/qdatasupport/guidata.cpp`: best GS / unclaimed imaging
  target by `elto`, emitting `ADCS_POINT_*` and `PAYLOAD_IMAGE_*`. This is what
  condition-driven activities replace. `OrbitalEventGenerator`
  (`physicsclass.cpp`) only has TARGAOS/TMAX/TARGLOS.

## Work items

### 1. Queue fixes (done, uncommitted in `agent`)
- [x] `Event::is_ready(utc)` / `set_utcexec(utc)`: take a time, so a simulator uses simulated time (0 = wall clock, as before)
- [x] `condition_true()`: debounce counts *consecutive* true evaluations (`true_count` reset on false)
- [x] `CommandQueue::due_commands(cinfo, utc)`: the readiness/condition state machine, no Agent needed; `run_commands(..., utc=0.)` dispatches its result
- [x] Solo Events actually run (previously skipped forever): alone in a pass
- [x] More than one conditional Event can fire per pass (previous `break`)
- [x] `del_command(Event&)`: no `erase(ii--)` on the first element (UB); `del_command(pos)` bounds-checked
- [x] `sort()` by MJD, not by ISO string
- [x] Behaviour test (scratch, not checked in): sim-time readiness, repeat re-arm, debounce, solo, compound condition
- [ ] Decide whether to check the test in (there is no test harness in `agent/programs/tests` for the queue yet)

### 2. Standard requests
- [x] Register `request_adcs` and `request_camera` as default nops in `Agent` (validate, debug_log, return OK; bad args return GENERAL_ERROR_ARGS with usage)
- [x] Command vocabulary: `request_adcs point topo|lvlh|geoc|selc|icrf qx qy qz qw` (quaternion normalized), `request_camera snap frames rate inttime [tile]` (frames >= 0, 0 = continuous; tile >= 1 frames per file, default 1000; rate Hz > 0, inttime s > 0)
- [x] Parsers public and static for the simulator to reuse: `Agent::parse_adcs_point()`, `Agent::parse_camera_snap()`
- [ ] Payload/ADCS agents override them with real handlers

### 3. Conditions on Namespace 2.0 (done, uncommitted in `agent`)
- [x] `Equation` (`support/equation.h/.cpp`, in CosmosNamespace): infix with precedence, `and`/`or`/`not` or `&`/`|`/`!`, parsed once, names looked up at evaluation
- [x] `cosmosstruc::get_number(name)`: any numeric 2.0 entry as a double, NAN quietly if missing or not numeric
- [x] `Event` holds a parsed `Equation`; `condition_true()` uses it (1.0 `json_equation` no longer used by the queue)
- [x] `add_target_names()`: target names split out of `add_default_names()`, registered as `target[i]` and `target[<name>]`, refreshed in `Simulator::AddTarget`, `load_target`, `json_clone_node`, and the target clear. This fixes 2.0 target pointers left dangling when the vector grew.
- [x] `add_default_names()` clears the 2.0 table first, so `json_updatecosmosstruc()` is a full resync: names of elements removed when a vector shrinks no longer point at freed memory. Narrow refreshes (`add_target_names()`, and more like it) are for when only part of the cosmosstruc changed.
- [x] Tests (scratch, under ASan): parser/precedence/errors, 2.0 names, 1.0 names rejected, missing-name NAN, target by index/name across 50 reallocations, queue + debounce, shrink-then-resync via `json_updatecosmosstruc()`
- [ ] Event dictionary (`calc_events`/`load_dictionary`, used by agent_exec, agent_monitor, fast_propagator) is still 1.0: `json_parse` + `emap` handles + `json_get_string` for `${...}`. Move it to `Equation` or retire it with `events.dict` (DMT task 002); then deprecate `json_equation*`/`emap`.
- [x] Sun term: `node.loc.pos.sunradiance` (tested via `get_number()` and `Equation`)
- [ ] Note: copying a `cosmosstruc` copies its 2.0 name map, which still points into the source object. Only targets are refreshed so far (`json_clone_node`).
- [ ] Note: 1.0 `node_loc_pos_geod_v_*` entries point at the `s.*` fields (`jsonlib.cpp` ~8422), an existing bug

### 4. Simulation
- [x] `Simulator::LoadQueue(node[, file])`: per-node `CommandQueue` restored (`restore_commands()`, non-destructive) from `get_nodedir(realm, node)/temp/exec/.queue`, the file agent_exec's `save_commands()` writes. Loaded lazily on a node's first step; missing file = empty queue. `CosmosSimulator` now links `CosmosCommand`.
- [x] `Simulator::ParseCommands()`, called from `Propagate()` before `AttitudeStep()`: `due_commands(&state->currentinfo, currentutc)`, interprets recognized requests, and pushes every due Event onto `currentinfo.event` (SOST's SimRun picks these up via `writeInternalEvents`). Invalid requests are colored red.
- [x] `request_adcs point`: stored per node in `Simulator::attcommands` (not `loc_req.att`: the LVLH attitude propagator copies `loc_req.att.lvlh` into the attitude every step, and the slew code keeps its progress there)
- [x] `AttitudeStep()` honors the command first: frame+quaternion converted to ICRF at the current position each step (so lvlh/topo track), slerped at the `slewBodyAxis` rate limit. The command persists until the next `request_adcs point`; there is no "release to automatic" yet.
- [x] `request_camera snap` imaging session model: the queue fires the Event when its condition becomes true; the session is the "imaging allowed" gate. A frame is taken whenever allowed; after each frame imaging is disallowed for 1/rate; after `frames` frames it stays disallowed. The session ends when complete or when the condition goes false, which also re-arms the Event. Frames due within a step are all taken if the condition is true at the step. One event per session, at session end: utc = first frame, dtime = to end of last frame's integration, value = frames, red if short.
- [x] Tiles: frames are saved in tiles of up to `tile` frames (one file each); the take restarts after each tile, so continuous acquisitions are cut every tile. The simulator reports one event per tile (utc = first frame, dtime to end of last frame's integration, value = frames); the last, partial tile is reported when the session ends. Real payload handlers should write one file per tile.
- [ ] Data volume (`cbytes`/`dbytes`) per tile from the detector definition
- [x] Frame period is 1/rate only; integration time is ignored for timing (detectors: inttime ~100s of µs, interframe ~ms; if a request gets it wrong, frame rate wins). inttime only extends the reported dtime.
- [x] `frames = 0` is continuous: frames at `rate` until the condition goes false (a non-conditional continuous snap runs to the end of the simulation; its full tiles are reported, the last partial one is not)
 Sampling period from detector and altitude (an algorithm input, not a scheduler condition). Debounce so it can't rapid-fire. Log samples/bytes.
- [ ] Hook into orbital event generation: emit detector activity events alongside the existing ones (replacing any prior detector event generation; see open question)

## Open questions
- Node layout is realm-based: definition in `<realm>/nodes/<node>.json`, data
  folder `<realm>/nodes/<node>/` (`get_nodedir()`). The queue lives in the data
  folder. agent_exec/agent_monitor still use the old `get_cosmosnodes()` /
  `data_base_path()` tree (`immediate/exec`, `incoming/exec`, `temp/exec/.queue`)
  and need converting to realm paths; not urgent. `.command` files dropped in
  `incoming/exec` are polled into the queue (and deleted); `save_commands()`
  persists the queue to `temp/exec/.queue` for reload on startup.
- SOST's `scheduleNode()` (guidata.cpp) still emits its own ADCS_POINT/PAYLOAD_IMAGE
  events alongside queue-driven ones until it is retired.

## Status log
- 2026-10-11: created from the design discussion; queue bugs fixed in `agent` (uncommitted), builds clean, behaviour test passes
- 2026-10-12: conditions moved to Namespace 2.0 infix equations; target names by index and name; full cosmosv5 build clean, tests pass under ASan
- 2026-10-12: `add_default_names()` clears the table first (full resync); shrink/resync test passes under ASan
- 2026-10-12: `request_adcs`/`request_camera` default nops with reusable parsers; sun term is `node.loc.pos.sunradiance`; build clean, scratch test passes
- 2026-10-13: Simulator loads per-node `.queue` from the realm node folder and runs it each step; scratch test (timed point, conditional repeating snap, invalid request) passes; cosmosv5, SOST, DMT build clean
- 2026-10-13: AttitudeStep honors request_adcs point (slerp at the slew rate limit); request_camera snap imaging sessions; scratch test passes; cosmosv5 and SOST build clean
- 2026-10-13: frames = 0 is continuous imaging; frame period from rate only
- 2026-10-13: tiles (default 1000 frames, one file each) for request_camera snap; scratch test passes; cosmosv5 and SOST build clean
