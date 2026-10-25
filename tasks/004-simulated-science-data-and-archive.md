---
status: in-progress
created: 2026-10-24
updated: 2026-10-24
---

# Simulated science data, the SOSE archive, and loading it in SOST

## Summary

Generating simulated LVMM data is expensive, so it is not done during the
normal simulation step. Instead there are two passes over one archive:

1. **Pass 1** (cheap): propagatorv3 runs the simulation and the command queue
   (task 002) and writes telemetry and events into the realm's archive.
2. **Pass 2** (expensive, optional): propagatorv3 `{"data":1}` reads that
   archive's telemetry and tile events and renders each tile's L0 data into
   the archive.

The archive belongs to SOSE. SOST loads a time window of it (telemetry,
events, data) as a whole, and the Science Data Display lists its products.
The simulator writes the same layout the real SOSE archive will use, so SOST
has a single loading path.

Related: task 002 (imaging sessions and tile events), task 003 (albedo map,
needed for realistic radiance), SOST `tasks/` (Science Data Display, Archive
button).

## Decisions (2026-10-24)

- We define the format, and keep it simple: raw binary data plus an ENVI
  header per file. Use the existing ENVI library
  (`simulator/libraries/support/envi.h`; `envi_hdr` keys/values carry custom
  fields).
- Passive L0: 2-D arrays (cross-track × along-track) of 8 spectral channels,
  in tiles of a length to be decided. Active L0: 1-D along-track arrays of 3
  spectral channels, in tiles of similar length.
- The archive is part of SOSE. It is general (not inside the realm
  directory): `<cosmos>/archive/<realm>/<node>/{data,telemetry}/<yyyy>/<ddd>/`
  (decided 2026-10-24, second round). File names:
  `passive|active_yyyydddhhmmss.img|hdr` and
  `telemetry|event_yyyydddhhmmss.json`.
- SOSE needs a small server agent that returns either full data or header
  information only, for a time window.
- SOSE programs go in a separate project (new repo).
- Detector model: the provisional LVMM model below.
- Per-line and per-pixel geometry are L1 products. The L0 header carries only
  what L0→L1 needs to reconstruct them (see "L0 file contents").
- Binning/noise: the science team's intent is unknown; simulate something that
  looks recognizable for the GUI (assumption under "L0 file contents").
- SOSE repo: `git@bitbucket.org:cosmos-project/science-operations-support-engine.git`, checked out at `~/cosmos/src/tools/science-operations-support-engine` beside SOST.

## Provisional detector model (from the science team, 2026-10-24)

All values are provisional simulation constants, not verified flight
hardware. Keep the **physical detector**, the **L0 sampling geometry** and the
**science data products** separate in configuration and code.

### Physical detector (PCO panda CMOS, baseline UV/VIS)
- 2048 × 2048 pixels, 6.5 µm, 16-bit digitization
- Optical field of view 3° full angle; nominal altitude 40 km
- QE 0.65 visible, 0.60 infrared; read noise 5 e⁻ RMS per physical pixel;
  dark current 1 e⁻/pixel/s; full well 30,000 e⁻

### Passive mode
- 40.9836 Hz, 2 ms integration
- 8 simultaneous logical channels (no filter wheel): 300, 532, 690, 850,
  1064, 1350, 1560, 1650 nm. The four longest (850–1650) are virtual infrared
  channels, not physically acquired by the panda.
- L0 is what is downlinked after onboard summation, spatial binning and swath
  selection. Full panda frames are never generated.
- Swath ≈ 485 m, ≈ 20 cross-track samples; effective ground pixel ≈ 24.6 m
  cross-track × 38.7 m along-track (UV/VIS), ≈ 24 × 40 m (infrared)
- Generate the ground samples directly at the reduced resolution, not by
  rendering and averaging physical pixels
- Noise: photon shot noise and read noise, accounting for the binning; uint16 DN

### Active mode
- 33.3333 Hz, 30 ms integration
- Laser spot sampled by a 12 × 12 detector region (simulated internally),
  reduced to one return per wavelength: 532, 1064, 1560 nm
- L0 is a 1-D along-track series of 3-band measurements

### Priorities
Correct spatial coverage, acquisition cadence, spectral channels, realistic DN
distributions and approximate downlinked data volume. Don't block on
unavailable hardware specifications.

### Derived values (my arithmetic, check)
- Physical IFOV = 3° / 2048 = 25.6 µrad → 1.02 m at 40 km; full swath 2.09 km.
  485 m ≈ 474 physical pixels → 20 samples of ≈ 24 pixels.
- Ground speed at 40 km circular ≈ 1.62 km/s → 39.6 m per passive frame,
  48.7 m per active shot. So 38.7 m along-track is the frame spacing
  (contiguous strip). Smear over 2 ms is ≈ 3 m.
- Data volume (uint16): passive 20 × 8 × 2 = 320 B/frame ≈ 13.1 kB/s; active
  3 × 2 = 6 B/shot ≈ 200 B/s. A 1000-frame passive tile ≈ 320 kB, 24.4 s,
  ≈ 40 km of track.

## Proposed design (not yet approved where marked)

### Archive layout (implemented for telemetry)
Root is `$COSMOSARCHIVE`, else `<cosmosroot>/archive` (`get_cosmosarchive()`):
```
<archive>/<realm>/<node>/telemetry/<yyyy>/<ddd>/telemetry_<yyyydddhhmmss>.json   jtype:"soh" lines
<archive>/<realm>/<node>/telemetry/<yyyy>/<ddd>/event_<yyyydddhhmmss>.json       jtype:"event" lines
<archive>/<realm>/<node>/data/<yyyy>/<ddd>/passive_<yyyydddhhmmss>.img|hdr
<archive>/<realm>/<node>/data/<yyyy>/<ddd>/active_<yyyydddhhmmss>.img|hdr
```
- Time in the name is the first record or first frame (UTC).
- Telemetry/event files: JSON lines (what SOST's `ReadData()` already reads),
  one file per hour of record time, so a time window maps to few files.
- Events are filed by the simulation step that reported them, so a tile event
  (utc = first frame) can predate its file's first record by up to a tile.
- A file of the same name is replaced. Runs that overlap without the same
  start leave duplicate records; SOST de-duplicates soh by time slot, not
  events. **Open:** whether that needs handling.
- **Open:** simulated and real data in the same archive. Proposed: a
  `simulated = 1` header key; a simulation study uses its own realm.

### L0 file contents (proposed)
- Passive: samples = cross-track (≈ 20), lines = frames, bands = 8, data type
  12 (uint16), interleave BIL (one line per frame time), wavelength = the 8
  channels.
- Active: samples = 1, lines = shots, bands = 3, uint16, BIL.
- Custom header keys, enough for L0→L1 to rebuild per-pixel geometry from
  the header plus the DEM, without the telemetry archive:
  - **Timing:** utc of the first line's exposure start, line period, integration
    time, lines. Dropped or irregular frames: an explicit list of line offsets.
  - **Spacecraft state knots:** utc, selenocentric position and velocity,
    attitude quaternion (ICRF→body) and angular velocity, at the tile's start
    and end and at each telemetry sample between. Position: Hermite on pos+vel
    (error ≈ mm over a 30 s tile at 40 km). Attitude: slerp with angular
    velocity; the in-between knots cover slews that start or stop mid-tile.
  - **Instrument geometry:** camera name; body→camera quaternion; boresight;
    physical IFOV; L0 sampling: samples, physical pixels summed per sample
    cross-track and along-track, first physical column of the swath (passive),
    spot offset (active).
  - **References:** body and frame (Moon, selenocentric, with its orientation
    model), time system (UTC MJD), DEM product, detector configuration version,
    `provisional` and `simulated` flags.
  - **For queries only (not geometry):** footprint corners of the first and
    last lines, so SOSE can answer time/area requests from headers alone.
- Binning assumption, for a recognizable image (provisional, until the science
  team says otherwise): each L0 sample sums 24 physical columns × the ≈ 38
  rows the ground moves through in one frame period (≈ 900 pixels). Read noise
  then ≈ 150 e⁻ per sample, and the DN gain is chosen so a bright sunlit
  highland fills about half of 16 bits.

### Detector configuration (proposed)
Top-level `detectors` object in the node file (like `command_events`), keyed
by camera piece name, with separate `physical`, `l0` and `products` sections
and a `provisional` flag. Mode (passive/active) gives the file name prefix.

### Pass 1: propagatorv3 writes the archive (done)
- `{"archive":1}` writes every step's telemetry (`json_soh_payload`) and every
  event (`json_event_payload`) through `ArchiveLines` (micro-agent `datalib`)
  into the layout above. Not in batch mode.
- Event payload now carries `dtime`, `value` and `data` (the tile's frame count
  and request with its camera); soh payload carries `battcap`/`battlev` and no
  longer indexes a missing cpu device.
- Note: tile events give `dtime` in seconds; orbital events (UMBRA, LAND, MOON)
  give it in days. Nothing reads `dtime` units yet; pass 2 uses rate × frames.
- Tile events (task 002) already record camera, first-frame utc, frames, rate,
  inttime; they become the work list for pass 2.

### Pass 2: data generation
- For each tile event in a time window: interpolate position (Hermite on
  pos+vel) and attitude (slerp with angular velocity) from telemetry to each
  frame time; intersect each sample's line of sight with the DEM; radiance
  from albedo × geometry (task 003; constant albedo until it exists); add
  shot/read/dark noise for the binned pixel count; scale to DN; write .img/.hdr.
- Tiles are independent: parallel, resumable (skip existing), re-runnable
  without re-propagating.
- Code in the cosmosv5 simulator library; propagatorv3 `{"data":1}` runs it
  after pass 1 or alone on an existing archive.

### SOSE (new project)
- Archive server agent: request a time window, get headers only or full data
  for telemetry, events and L0.
- **Open:** how full data is delivered (agent requests are small; file
  transfer or websocket for L0).

### SOST
- Archive button loads a time window from the SOSE archive (directly from disk
  at first, then via the server agent): telemetry and events through
  `UpdateData()`, L0 headers into a product list.
- Science Data Display: counts per instrument/level and per target from the
  headers; the Data Management Tool button opens the selected tile.

### Globe (lower priority)
Equirectangular albedo texture (from task 003) on the Moon globe, lit by the
globe's own sun and DEM normals (stored albedo has the shading removed). A
quick preview could use `w` from the 1 pixel/degree WAC Hapke parameter map,
or the 643 nm WAC tiles reduced to ≈ 4 pixels/degree.

## Work items

- [x] Archive root and node path (`<cosmos>/archive/<realm>/<node>/`); L0 geometry is L1, header carries reconstruction inputs
- [ ] Settle: simulated flag; duplicate events from overlapping runs; `dtime` units (s vs days)
- [x] Archive path/name helpers: `get_cosmosarchive()`, `get_archivedir()`, `archive_name()`, `ArchiveLines` (micro-agent `datalib`)
- [x] Pass 1: propagatorv3 `{"archive":1}` writes hourly telemetry/event files
- [ ] SOST: load a time window from the archive (telemetry + events)
- [ ] Detector configuration in the node file (physical / l0 / products)
- [ ] Pass 2 skeleton: tile events → geolocated samples → constant-albedo radiance → noise → DN → ENVI files
- [ ] Pass 2 active mode
- [ ] Plug in the albedo map and forward model (task 003)
- [ ] SOSE project and archive server agent
- [ ] SOST: L0 product list in the Science Data Display; Data Management Tool opens a tile
- [ ] Globe albedo texture

## Status log
- 2026-10-24: created from the design discussion; format, archive location, file names, SOSE project and provisional detector model decided
- 2026-10-24: archive moved to `<cosmos>/archive/<realm>/<node>/`; L0 header holds geometry-reconstruction inputs, per-line/pixel geometry is L1; binning: anything recognizable for now
- 2026-10-24: pass 1 done. Scratch copy of lunar, 8 h at 10 s from 61337.75: 2880 soh lines over 8 hourly files (no gaps, crosses midnight into 2026/298), events incl. 88 camera tiles with frames/dtime/request; 4.7 MB. Fixed on the way: an explicit `initialutc` was doubled for flo/kep/phys/sso orbits with epoch 0 (Simulator added now to an absolute base; kep added now twice). Full cosmosv5 and SOST build clean. Committed: micro-agent c031161, agent aa6497e.
- 2026-10-24: SOSE repo created on Bitbucket and scaffolded (CMake against COSMOSv5, `archive_query` lists the archive files for a window, its task 001 = archive server agent). Pushed (89df94e). It needs the micro-agent datalib helpers (c031161).
