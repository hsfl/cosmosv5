---
status: in-progress
created: 2026-10-24
updated: 2026-10-27
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
  in tiles of a length to be decided (87 superpixels, rows by acquisition). Active L0: 1-D along-track arrays of 3
  spectral channels, in tiles of similar length.
- The archive is part of SOSE. It is general (not inside the realm
  directory): `<cosmos>/archive/<realm>/<node>/{data,telemetry}/<yyyy>/<ddd>/`
  (decided 2026-10-24, second round). File names:
  `passive|active_yyyydddhhmmss.img|hdr` and
  `telemetry|event_yyyydddhhmmss.json`.
- SOSE needs a small server agent that returns either full data or header
  information only, for a time window.
- SOSE programs go in a separate project (new repo).
- Detector model: the Phase B1 baseline below (replaced the provisional model 2026-10-27).
- Per-line and per-pixel geometry are L1 products. The L0 header carries only
  what L0→L1 needs to reconstruct them (see "L0 file contents").
- Binning/noise: the science team's intent is unknown; simulate something that
  looks recognizable for the GUI (assumption under "L0 file contents").
- SOSE repo: `git@bitbucket.org:cosmos-project/science-operations-support-engine.git`, checked out at `~/cosmos/src/tools/science-operations-support-engine` beside SOST.

## Detector model: Phase B1 baseline (instrument team, design report 2026-10-26)

Supersedes the 2026-10-24 provisional model (single panda, 20 samples of
≈ 24 × 39 m, four "virtual" infrared channels). All values are preliminary,
subject to later confirmation. Keep three concepts separate in configuration
and code: **physical detector pixels**, **acquired detector rows**, and
**downlinked L0 superpixels**. No filter wheel, no full-frame imaging.

### Instrument
Pushbroom multispectral imager: one telescope (≈ 3° full-angle FOV, ≈ 80 mm
aperture), dichroics split the beam to three cameras, each with a bandpass
filter mosaic whose stripes run across-track and are stacked along the
direction of travel.

| Camera | Detector | Pixels | Pitch | Channels (nm) | Superpixel |
|--------|----------|--------|-------|---------------|-----------|
| UV/VIS | PCO Panda 4.2 BI CMOS | 2048 × 2048 | 6.5 µm | 300, 532, 690, 850 | 7 × 7 |
| NIR | SU640CSX InGaAs | 640 × 512 | 12.5 µm | 1064 | 6 × 6 |
| SWIR | SU640CSX InGaAs | 640 × 512 | 12.5 µm | 1350, 1560, 1650 | 6 × 6 |

Because the filter stripes are offset along-track, each channel sees a given
ground point at a slightly different time.

### Passive mode
- 40.98 Hz, 2 ms integration, reference altitude 40 km.
- Each acquisition reads, per channel, only the rows of one superpixel (7 rows
  UV/VIS, 6 rows NIR/SWIR) inside that channel's filter stripe.
- Onboard: row selection → dark subtraction → summation into superpixels →
  swath selection (87 superpixels cross-track) → lossless compression.
- Superpixel GSD ≈ 19.2 × 19.2 m. Rows are **not** contiguous: keep the
  actual acquisition spacing (≈ 39.6 m, see derived values), with gaps.
- Simulate the L0 superpixels directly; never render full detector arrays.

### Active mode
- Same receiver and cameras. Lasers at 532 (UV/VIS), 1064 (NIR), 1560 nm
  (SWIR).
- 33.33 Hz, 30 ms integration; 12 × 12 pixel ROI around the return on each
  camera, reduced onboard to one measurement per wavelength.
- L0: 1-D along-track spectral track, 3 values per observation.

### Priorities (in order)
1. Lunar surface intersection and geolocation
2. Pushbroom acquisition geometry
3. Spectral differences between the 8 passive channels
4. Acquisition timing
5. Spatial aggregation into superpixels
6. Approximate detector noise and SNR
7. Plausible reduced L0 data volumes

### Derived values (my arithmetic, check)
- Plate scale from the given GSD: UV/VIS 19.2 m / 7 = 2.74 m per pixel
  (68.6 µrad, effective focal length ≈ 95 mm); NIR/SWIR 19.2 m / 6 = 3.2 m
  (80 µrad, ≈ 156 mm). So the two camera types sit behind different relay
  magnifications, not one shared focal plane.
- The InGaAs 640 × 80 µrad = 2.93° matches the 3° FOV. The panda at 68.6
  µrad would span 8°, so only ≈ 760 × 760 of its pixels fall in the 3° field.
- Swath 87 × 19.2 m = 1.67 km (2.39°): 609 panda columns, 522 of the 640
  InGaAs columns.
- Ground speed at 40 km ≈ 1.62 km/s → 39.6 m between passive acquisitions.
  With 19.2 m superpixels and one superpixel row per acquisition, about 48%
  of the track is covered (19.2 m strips with ≈ 20.4 m gaps). Smear in 2 ms
  ≈ 3.2 m (≈ 1 pixel).
- Channel time offset = along-track stripe separation / ground speed. The
  field is circular, so a stripe that still spans the full 87-superpixel
  swath (half-width 20.9 mrad) must sit within ±15.8 mrad of the boresight
  along-track (±0.63 km). Offsets therefore reach about ±0.39 s, not the
  ±0.65 s the full 3° field would allow.
- Active: 48.7 m between shots. The 30 ms integration fills the whole
  33.33 Hz period, so each return is smeared ≈ 49 m along-track. The ROI is
  ≈ 33 m (UV/VIS) / 38 m (InGaAs) on the ground.
- Volume before compression: passive 87 × 8 = 696 samples per acquisition,
  2.8 kB at 32 bits (1.4 kB at 16 bits) → 114 kB/s (57 kB/s). Active
  3 × 4 B × 33.33 Hz ≈ 400 B/s. Compression ratio: assume 2:1 until given.

### Open (for the instrument team)
- Filter stripe positions: which rows each channel reads (or its along-track
  angle from the boresight). Placeholder: evenly spaced within ±15 mrad
  (UV/VIS −15, −5, 5, 15; NIR 0; SWIR −15, 0, 15), ascending wavelength in
  the direction of travel.
- Whether all cameras share one acquisition trigger (assumed yes).
- Superpixel sum range: 49 × 16-bit (panda) or 36 × 14-bit (InGaAs, assumed)
  dark-subtracted pixels needs ≥ 22 bits and can go negative. Assumed L0
  sample is signed 32-bit (ENVI type 3).
- InGaAs noise: QE, read noise, dark current, full well, bit depth are not
  given. Placeholders: QE 0.7, read noise 50 e⁻, dark 1e4 e⁻/s, full well
  170,000 e⁻, 14 bit. Panda keeps the earlier values: QE 0.65, read noise
  5 e⁻, dark 1 e⁻/s, full well 30,000 e⁻, 16 bit.
- Pulsed or CW lasers, spot size, and the ROI reduction (peak, sum,
  background-subtracted sum). Assumed: background-subtracted sum over the
  ROI.
- Which node-file camera pieces are LVMM. VMMO now has `camera1`–`camera4`.

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
- Passive: samples = 87 superpixels cross-track, lines = acquisitions, bands
  = 8, data type 3 (int32, see Open), interleave BIL, wavelength = the 8
  channels. Line *i* is acquisition *i*, which is one time for every band.
  Each band views a different ground strip at that time, and L1
  co-registers them using the per-band along-track offset in the header.
  Lines are not contiguous on the ground.
- Active: samples = 1, lines = observations, bands = 3, int32, BIL.
- Custom header keys, enough for L0→L1 to rebuild per-pixel geometry from
  the header plus the DEM, without the telemetry archive:
  - **Timing:** utc of the first line's exposure start, line period, integration
    time, lines. Dropped or irregular frames: an explicit list of line offsets.
  - **Spacecraft state knots:** utc, selenocentric position and velocity,
    attitude quaternion (ICRF→body) and angular velocity, at the tile's start
    and end and at each telemetry sample between. Position: Hermite on pos+vel
    (error ≈ mm over a 30 s tile at 40 km). Attitude: slerp with angular
    velocity; the in-between knots cover slews that start or stop mid-tile.
  - **Instrument geometry:** body→instrument quaternion; boresight; per band:
    camera, physical IFOV, superpixel size (pixels across × along), first
    physical column of the swath, first acquired row (or its along-track
    angle) (passive), ROI centre (active).
  - **References:** body and frame (Moon, selenocentric, with its orientation
    model), time system (UTC MJD), DEM product, detector configuration version,
    `provisional` and `simulated` flags.
  - **For queries only (not geometry):** footprint corners of the first and
    last lines, so SOSE can answer time/area requests from headers alone.
- Sample value: the sum of the superpixel's dark-subtracted physical DN (49
  panda or 36 InGaAs pixels). Noise per superpixel: shot noise on the signal
  and dark charge, plus read noise × √n (n = 49 or 36), plus residual dark
  shot noise. Each camera's gain comes from its full well and bit depth.
- Also record the estimated compressed size (until the ratio is known).

### Detector configuration (proposed)
Top-level `instruments` object in the node file (like `command_events`).
`lvmm` contains:
- `cameras`: `uvvis`, `nir`, `swir`, each with a `piece` and `detector`
  name, its `physical` detector (`cols`, `rows`, `pitch` m, `ifov` rad, `qe`
  per wavelength, `read_noise` e⁻, `dark_current` e⁻/s, `full_well` e⁻,
  `bits`) and its `acquisition` (`superpixel` [across, along], `swath_cols`,
  `first_col`, and `stripes`: wavelength → `along` rad (+ = ahead) and
  `first_row`).
- `modes`: `passive` (`rate` Hz, `inttime` s, `channels` nm) and `active`
  (also `lasers` nm, `roi`, `reduction`). The mode name is the file name
  prefix.
- `l0`: `samples`, `datatype`, `interleave`, `compression_ratio`.
- `fov`, `aperture`, `reference_altitude`, `provisional`, `baseline`, and
  `notes` listing the placeholders.
- Implemented in `~/cosmos/realms/lunar/nodes/vmmo.json` (2026-10-27).
  Piece mapping is a placeholder: `camera1` uvvis, `camera2` nir,
  `camera3` swir. The DMT node save (`json_dump_node` plus
  `writeCommandEvents`) does not yet keep `instruments`.

### Pass 1: archive_simulate writes the archive (done; was propagatorv3 `{"archive":1}`)
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
  acquisition time; per band, intersect each superpixel's line of sight
  (stripe row offset, 87 columns) with the DEM; radiance from albedo ×
  geometry per wavelength (task 003; a per-channel constant albedo until it
  exists, so bands still differ); integrate over the superpixel footprint
  (≈ 19 m, a few DEM samples); add shot/read/dark noise for its pixel count;
  scale to DN; write .img/.hdr.
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
- [x] Pass 1: hourly telemetry/event files (now ground-station `archive_simulate`)
- [x] SOST: load a time window from the archive (telemetry + events)
- [ ] Confirm Phase B1 open items with the instrument team (stripe rows, L0 bit depth, InGaAs noise, laser/ROI reduction, camera pieces)
- [x] Instrument configuration in the node file (`instruments.lvmm`: cameras / modes / l0)
- [ ] DMT: preserve `instruments` on node save
- [x] Pass 2 skeleton: tile events → geolocated samples → constant-albedo radiance → noise → DN → ENVI files
- [ ] Pass 2: verify DEM altitude semantics (`map_dem_alt` assumed height above RMOONM); sub-sample the superpixel footprint once albedo varies; smear
- [ ] Imaging only while pointed for it (image_passive fires during point_target staring and slews)
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
- 2026-10-24: SOST Archive button opens a dialog: node (or all), begin/end UTC defaulting to the archived span, Load, or "From file..." (the old single-file load). `GuiClock::ArchiveDir/ArchiveNodes/ArchiveSpan/ReadArchive` (tool-libraries `guidata`) read whole hourly files covering the window as REQUESTED; written with std::filesystem and get_cosmosroot, not the new datalib helpers, so tool-libraries still builds against cosmos-core. `UpdateData` now also reads soh `powerout`, `battcap`, `battlev`. Harness test on the pass 1 archive, 21:36–00:28: 4 files per kind, 1440 soh + 573 events, positions and battery populated.
- 2026-10-27: detector model replaced by the Phase B1 baseline (design report 2026-10-26): three cameras (Panda UV/VIS, two SU640CSX for NIR and SWIR) behind one 3° telescope, filter-stripe pushbroom, 7×7 / 6×6 superpixels ≈ 19.2 m, 87 cross-track, rows spaced ≈ 39.6 m with gaps. L0 is int32 BIL by acquisition with per-band along-track offsets; config moves to `instruments.lvmm`. Open items listed for the team.
- 2026-10-27: `instruments.lvmm` added to live `lunar/nodes/vmmo.json` with placeholders: stripes within ±15 mrad, since the circular 3° field caps along-track offsets at ±15.8 mrad for the full swath; computed rows: Panda 802/948/1093/1239, SWIR 66/253/440, first columns 719 (Panda) and 59 (InGaAs). Other keys unchanged; a propagatorv3 run on lunar loads it. Committed: tool-libraries 32cf6d8 (SOST archive dialog), cosmosv5 a09a602.
- 2026-10-27: pass 2 skeleton. `Physics::L0Sim` (agent `l0simclass`, target `CosmosL0Sim`) reads `instruments.lvmm`, the archived telemetry (Hermite position, slerp attitude) and the tile events of each mode's `event` (image_passive/image_active), and writes passive tiles as int32 BIL ENVI (87 × frames × 8) with the header keys above (timing, per-band camera/ifov/superpixel/stripe/gain, knots, footprint). Line of sight per superpixel from the body frame (boresight +Z, along-track +X), sphere then 3 DEM refinements, Lambert constant albedo per band, solar irradiance (≈ E-490), shot/dark/read noise per superpixel pixel count. propagatorv3 `{"data":1}` runs it after pass 1, or alone with `runcount 0` over initialutc–endutc; `dataoverwrite`. Active tiles are skipped for now. micro-agent `datalib` gained `archive_list()`/`archive_parse_name()` (the SOSE/SOST listing logic). vmmo.json: modes name their command event, `forward` placeholders, snap requests set to the B1 rates (40.98 Hz/2 ms, 33.33 Hz/30 ms). Found on the way: propagatorv3 never slewed (Propagate() without enabletorque, and ParseSatFile's Iterative attitude propagator undoes slews); now `torque` (default 1) and `attitude` (default lvlh, as SOST), so every pass 1 archive made before this has unpointed attitude. One orbit from 61340.671528 at 10 s: 21 passive tiles in ≈ 24 s; nadir tiles ≈ 2.0–2.2 km swath × 40 km; 532 nm ≈ 14.5k e⁻/pixel at 75°S, SNR ≈ 800. Tiles taken while staring at a polar target or slewing have wide or off-Moon footprints (they're what was commanded).
- 2026-10-27: archive moved out of flight code (micro-agent runs on the flight processor). micro-agent `datalib` is back to 5e1539f; ground-station has `libraries/archive` (`CosmosArchive`: get_cosmosarchive, get_archivedir, archive_name, archive_list, archive_parse_name, ArchiveLines) and `libraries/science` (`CosmosL0Sim`, namespace `Science`). New ground-station program `archive_simulate` runs pass 1 (propagate with LVLH attitude and slewing, archive telemetry and events) and pass 2 (L0); propagatorv3 lost `archive`/`data`/`dataoverwrite` (keeps `torque`, `attitude`). Same 21 tiles and values as before over one orbit; pass 1 0.4 s per orbit. SOST will get archive data from SOSE over the network (JSON requests; L0 bytes over a bulk channel to be decided); direct disk reading stays only for development.
- 2026-10-27: virtual cameras. VMMO's `camera1`/`camera2` renamed `lvmm_passive`/`lvmm_active` (pieces, devices, strucs, tsen, on/off and snap command events); the three physical cameras (uvvis/nir/swir) are internal to `instruments.lvmm` and have no pieces; each mode names its virtual camera (`"camera"`), and L0Sim picks the mode from the tile's snap camera (header key `camera`). Renaming exposed a heap overflow: `State::Init` always built `camera1`–`camera4` and the overlay added the renamed ones, giving 6 CAM devices, and `update_metrics` wrote `targetstruc::cover[4]` for each. Now default cameras are built only when the node file defines none, and `update_metrics` stops at the size of `cover`. `camera3`/`camera4` remain in vmmo.json until removed in DMT.
