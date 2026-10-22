---
status: in-progress
created: 2026-10-14
updated: 2026-10-22
---

# Lunar albedo map for detector simulation

## Summary

The simulator needs the brightness of each patch of lunar surface seen by a
detector, for any sun and viewing geometry. To do that, store **albedo** (with
illumination and local tilt removed), not a brightness image, and re-apply the
sun angle, viewing angle and local slope at simulation time. Code goes in the
cosmosv5 simulator; data goes in `resources/mapping/moon/`.

Detector bands (from the source document):
- Passive (reflected sunlight): 300, 532, 690, 850, 1064, 1350, 1560, 1650 nm
- Active (laser, zero phase): 532, 1064, 1560 nm

Decisions (2026-10-14):
- A download script fetches the source data and builds the converted product
  locally. Neither is committed: `resources/mapping/moon/albedo_76/` is
  gitignored (decided 2026-10-22, option 3 below).
- The stored product is our own format: tiled like the DEM to stay under git
  limits, unsigned 16-bit values (albedo 0–1 scaled to 0–65535), at the
  native 400 m resolution.
- Polar regions (above 70°) are filled by interpolation.

## Background

### Base source: LROC WAC Hapke-normalized mosaic (`WAC_HAPKE`)

Checked 2026-10-14 against the product page, README and the label of
`WAC_HAPKE_643NM_E350N0450.IMG`:

- Photometrically normalized radiance factor (I/F), normalized with Hapke
  parameter maps (Sato et al. 2014, JGR Planets 119, 1775–1805,
  doi:10.1002/2013JE004580) to **i = g = 60°, e = 0°**. The i, e, g used for
  the normalization came from the WAC stereo terrain model (GLD100), so local
  slopes are already removed. Product citation: Sato et al. 2017, Icarus 296,
  216–238.
- 7 bands: 321, 360, 415, 566, 604, 643, 689 nm.
- 400 m/pixel at the equator (76 pixels/degree), equirectangular, sphere
  radius 1737.4 km, east-positive longitude.
- Coverage 70°N–70°S only: 8 tiles per band, each 70° latitude × 90° longitude
  (`WAC_HAPKE_<band>NM_E350[N|S]<0450|1350|2250|3150>`).
- Each tile is a PDS3 `.IMG`: one label record (`RECORD_BYTES = 27360`), then
  5321 lines × 6840 samples of little-endian 32-bit float (`PC_REAL`), band
  sequential. Null is `16#FF7FFFFB#`, with the other PDS special values
  `FF7FFFFC`–`FF7FFFFF`. 138.86 MB per tile, so about 1.1 GB per band and
  about 7.8 GB for all 7 bands.
- Download: `https://pds.lroc.im-ldi.com/data/LRO-L-LROC-5-RDR-V1.0/LROLRC_2001/DATA/MDR/WAC_HAPKE/<tile>.IMG`
- The 100 m `WAC_GLOBAL` 643 nm mosaic was rejected. It is 8-bit GeoTIFF with
  no radiometric scale, and its normalization geometry isn't documented. It's
  a basemap, not albedo.

### Band coverage by source

| Detector band | Source | Notes |
|---|---|---|
| 300 | WAC 321 | slight extrapolation |
| 532 | WAC 415 / 566 | interpolate |
| 690 | WAC 689 | direct |
| 850, 1064, 1350, 1560, 1650 | not WAC | candidates: Chandrayaan-1 M3 (430–3000 nm, about 140 m), Kaguya MI (to about 1550 nm); 1650 is beyond MI. Not yet verified. |
| active 532, 1064, 1560 | — | needs zero-phase albedo, which includes the opposition surge (Hapke BS0, hS). LOLA measures 1064 nm directly. |

### Hapke parameters (LROC "Resolved Hapke Parameter Maps")

Hapke 2012 model. At 643 nm the mapped parameters are w (single scattering
albedo), b and c (double-lobed Henyey-Greenstein phase function), BS0 and hS
(shadow-hiding opposition effect amplitude and width). They are solved per
1° × 1° tile (64800 tiles, about 30 km). Not yet known: whether the other WAC
bands have parameter maps, the fixed values (theta-bar, porosity), and where the
maps can be downloaded (Sato et al. 2014).

### Hapke parameter maps: `WAC_HAPKEPARAMMAP`

Published by LROC (data.lroc.im-ldi.com/lroc/view_rdr/WAC_HAPKEPARAMMAP).
There is a 9-band product per WAC band (`WAC_HAPKEPARAMMAP_<321..689>NM`) and a
63-band product (`_7BAND`). The parameter order is w, b, c, Bc0, hc, Bs0, hs,
θ, φ. Fixed values: Bc0 = 0, hc = 1, θ = 23.657°, φ = 1.0. The grid is 1 pixel
per degree, 70°N–70°S. Hapke 2012 model, double-lobed Henyey-Greenstein phase
function. File format not yet checked.

### 850–1650 nm candidates (checked 2026-10-14)

**Chandrayaan-1 M3, Level 2** (planetarydata.jpl.nasa.gov/img/data/m3/CH1M3_0004/):
- Global mode: 85 bands, 430–3000 nm, 300 pixels across track. 140 m/px from
  the 100 km orbit (OP1, OP2A/B) and 280 m/px from the 200 km orbit (OP2C,
  2009-05-20 onward). Covers more than 95% of the Moon.
- Reflectance is the radiance factor, normalized to i = 30°, e = 0° with an
  empirical limb-darkening function from highland units. It is not a Hapke
  model. Thermal removal is applied, which doesn't matter below about 2 µm.
  The ground-truth correction was turned off. Cross-track residuals remain
  (correction tables were added in 2012).
- Stored as **strips in instrument geometry** ("pixel-located, resampled"),
  one per observation, with LOC/OBS backplanes. No map-projected global mosaic
  is in the PDS, so we would have to project, photometrically match and mosaic
  the strips ourselves. Pointing is degraded after star tracker loss (OP2B/C).
- Whether the main reflectance used local topography is not yet confirmed.
  (The supplemental 1489 nm band is explicitly corrected to a sphere,
  keeping topographic shading.)

**Kaguya (SELENE) MI, USGS map-projected mosaics**
(`https://asc-pds-services.s3.us-west-2.amazonaws.com/mosaic/Lunar_MI_multispectral_maps/`):
- 9 bands: 414, 749, 901, 950, 1001, 1000, 1049, 1248, 1548 nm. One file per
  band (`Lunar_Kaguya_MIMap_Band<n>_<id>_<nm>nm_65N65S_512ppd.tif`, about 23 GB
  each, plus a 2 GB `.ovr` of overviews).
- 512 pixels/degree (59 m), 65°N–65°S, map-projected, "topographically
  corrected reflectance" (shading removed, Ohtake et al. 2013). The reference
  geometry and value scaling are not yet confirmed.
- Format from the header: BigTIFF, 184320 × 66560, signed 16-bit, LZW
  compressed, 256 × 256 tiles, no-data −32768. Tiles can be read separately with
  HTTP range requests, so the full 23 GB doesn't have to be downloaded.
- Gives 850 (interpolated 749/901), 1064 (1049), 1350 (1248/1548) and 1560
  (1548). 1650 needs a short extrapolation from 1548.

### Gaps

- **Poles above 70°** (VMMO targets such as Shackleton). Candidate: LOLA
  1064 nm albedo (Lucey et al. 2014), measured by LOLA's own laser at zero
  phase, so it's insensitive to topography and sun angle. Polar grids are
  about 1 km (e.g. `LDAM_50S_1000M`); global grids are 3–8 km. Single
  wavelength. Not yet verified.
- **850–1650 nm.** See the band table. Product, resolution and photometric
  correction not yet verified.
- **Slopes for re-applying geometry.** `resources/mapping/moon/lola_16` is
  0.25° (about 7.6 km), too coarse for 400 m–1 km slopes. Use a finer LOLA
  (or GLD100) DEM, ideally the same terrain model the normalization used.

### Existing simulator pieces

- `simulator/libraries/support/demlib.*`: ENVI tiled DEM reader
  (`map_dem_alt()`). The DEM tiles store elevation plus surface normal
  (4 bands). An albedo map could use the same tiling and lookup.
- `resources/mapping/moon/{body.dat,dems5.dat,lola_16/}`: current Moon DEM
  and its index.

### Kaguya MI facts confirmed from the GeoTIFF metadata

reflectance = value × 2e-5. No data is −32768. The grid is −180°..180° longitude,
65°N..65°S, 0.001953125° per pixel, on a 1737.4 km sphere. Reference geometry
is believed to be i = 30°, e = 0°, g = 30° (Ohtake et al. 2013); still to verify.

`WAC_HAPKEPARAMMAP_7BAND.IMG` is 12 MB: a PDS3 label (5 records of 1440 bytes),
then 140 lines × 360 samples × 63 bands of 32-bit float, band sequential,
null `FF7FFFFB`, 1 pixel per degree, 70°N–70°S, longitude 0–360.

### Proposed stored format (storage location decided; layout not yet approved)

- `resources/mapping/moon/albedo_76/` at 76 pixels/degree (400 m), with an
  index file like `dems5.dat`
- 20° × 20° tiles (1520 × 1520 pixels), 162 tiles, about 37 MB each; raw data
  plus an ENVI `.hdr` per tile (band wavelengths, scale)
- 8 bands interleaved per pixel: w at 300, 532, 690, 850, 1064, 1350, 1560,
  1650 nm. Active (laser) bands are computed from w plus the opposition
  parameters, so they need no storage of their own.
- uint16, w = value / 65535, 0 = no data
- Separate 1 pixel/degree Hapke parameter file (b, c, BS0, hS per band; bands
  beyond 689 nm carry the 689 nm values forward)
- Poles filled by interpolation above 70° (WAC bands) and 65° (MI bands)
- **Open:** the total is about 6 GB (3–4 GB compressed), well over GitHub's
  recommended repo size. Options: (1) Git LFS (needs a paid quota), (2) commit
  a 1 km version (about 1 GB) and have the script regenerate 400 m,
  (3) keep the tiles out of git, built by the script and gitignored.
  **Decided 2026-10-22: option 3.** The script must therefore be reliable and
  repeatable (resumable downloads, checksums), and the simulator must cope
  with the tiles being absent (fall back to a constant albedo, with a warning).

## Work items

- [x] Storage: download script builds the product locally; tiles gitignored, not committed (option 3); own tiled uint16 format at 400 m
- [x] Stored quantity: single-scattering albedo w per band
- [ ] Define the tile format (tile size, header, scaling, null value) and its reader
- [ ] Download script for the source tiles
- [ ] Get the Hapke model form and parameters used for the normalization
      (Sato et al. 2014/2017: which parameters are mapped vs fixed, and on what
      grid), so normalized I/F can be inverted to single-scattering albedo `w`.
- [ ] Converter: `WAC_HAPKE` tiles to the stored albedo map (`w` per band, or
      normal albedo), at native 400 m resolution
- [ ] Finer lunar DEM for slopes; check it matches the GLD100 the normalization used
- [ ] Simulator lookup: albedo at (lat, lon, band), interpolated
- [ ] Forward model: reflectance at given i, e, g with local slope, from the
      stored albedo and the Hapke parameters
- [ ] Polar albedo (above 70°) from LOLA 1064 nm; decide how to extend it to
      other wavelengths
- [x] 850–1650 nm source: Kaguya MI USGS mosaics (1650 extrapolated from 1548); M3 kept in reserve as a 1650 nm spectral-shape check
- [ ] Active bands: zero-phase albedo at 532, 1064 and 1560 nm (opposition surge; check against LOLA 1064)

## Status log
- 2026-10-14: created. `WAC_HAPKE` chosen as base; format confirmed from the 643 nm tile label.
- 2026-10-14: real detector bands recorded (passive 300–1650 nm, active 532/1064/1560 nm); storage decisions; Hapke parameter findings
- 2026-10-14: store w; investigating M3 for 850–1650 nm
- 2026-10-14: M3 L2 and Kaguya MI mosaics investigated (see Background); WAC_HAPKEPARAMMAP found
- 2026-10-14: Kaguya MI chosen for 850–1650 nm
- 2026-10-14: MI scaling/grid and Hapke map format confirmed; stored format proposed; repo-size question open
- 2026-10-22: repo size settled with option 3: tiles built by the script, gitignored in resources
