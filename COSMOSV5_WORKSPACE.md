# COSMOSv5 Workspace Architecture

## Structure

`hsfl/cosmosv5` is a **flat workspace** containing all 7 COSMOS layers plus a
resources submodule as git submodules:

```
cosmosv5/
  thirdparty/      → hsfl/cosmosv5-thirdparty
  kernel/          → hsfl/cosmosv5-kernel
  micro-agent/     → hsfl/cosmosv5-micro-agent
  simulator/       → hsfl/cosmosv5-simulator
  agent/           → hsfl/cosmosv5-agent
  modules/         → hsfl/cosmosv5-modules
  ground-station/  → hsfl/cosmosv5-ground-station
  resources/       → hsfl/cosmosv5-resources  (update = none — opt-in only)
  CMakeLists.txt
  setup.sh / setup.bat
```

Previously each layer repo contained its dependency as a nested `deps/` submodule
(agent contained simulator, simulator contained micro-agent, etc.), producing
duplicate checkout trees. That was removed. Each layer repo's cmake now requires
`COSMOS_SOURCE` to point at the workspace root.

---

## Cloning and Initializing

Do **not** use `git clone --recurse-submodules` — it would download all layers
and the resources submodule regardless of what you need. Instead clone the
workspace and use the setup script to initialize only the layers required:

```bash
git clone https://github.com/hsfl/cosmosv5.git
cd cosmosv5
./setup.sh agent          # kernel + micro-agent + simulator + agent
```

On Windows use `setup.bat` instead of `./setup.sh`.

The setup scripts also set `push.recurseSubmodules=check` (local `.git/config`) in the
workspace and each initialized submodule, so git refuses a workspace push that references
an unpushed submodule commit. See [Keeping Up to Date](#keeping-up-to-date).

### Layer options for setup.sh / setup.bat

| Argument | Submodules initialized |
|---|---|
| `kernel` | kernel |
| `micro-agent` | kernel, micro-agent |
| `simulator` | kernel, micro-agent, simulator |
| `agent` | kernel, micro-agent, simulator, agent  ← **recommended default** |
| `modules` | thirdparty, kernel, micro-agent, simulator, agent, modules |
| `ground-station` | thirdparty … ground-station |
| `all` | everything including resources (~21 MB physics data files) |

`thirdparty` (jpeg/png) is only needed from `modules` and above.

You can also initialize submodules directly without the script:

```bash
git submodule update --init kernel micro-agent
git config push.recurseSubmodules check   # manual init skips the push check
```

### Resources submodule

The `resources/` submodule (`hsfl/cosmosv5-resources`) contains the physics data
files needed to run propagation programs (gravitational models, JPL ephemeris,
IERS data, WMM). It is marked `update = none` in `.gitmodules` and is never
initialized automatically. To get it:

```bash
./setup.sh all
# or directly (the -c flag overrides update=none):
git -c submodule.resources.update=checkout submodule update --init resources
```

After building, `cmake --install` copies the contents of `resources/` (`general/`,
`logo/`) to `${CMAKE_INSTALL_PREFIX}/resources/`. Programs locate resources via the
`COSMOS` or `COSMOSRESOURCES` environment variable, or the default
`/usr/local/cosmos/resources`.

> **Note:** `wmm_2025.cof` is not yet included in the resources repo. Simulations
> using dates after 2025-01-01 will fail to load the magnetic model.

---

## Keeping Up to Date

The workspace records a specific commit for each layer submodule. Pulling the workspace
updates those recorded commits but does **not** move your checked-out submodules.

**Quick reference:**

```bash
git pull && git submodule update        # sync initialized layers to recorded commits
git -c submodule.resources.update=checkout submodule update --init resources   # resources (skipped otherwise)
git submodule update --remote           # developers: move layers to latest remote main
```

- `git submodule update` only touches initialized submodules; rerun `./setup.sh <layer>`
  to add a higher layer later.
- `git submodule status` shows each layer's state: a leading `+` means the checked-out
  commit differs from the recorded one, `-` means not initialized.
- `resources` is `update = none`, so plain `git submodule update` silently skips it — the
  `-c` override is required (add `--remote` to take the latest resources). Rerun
  `cmake --install .` afterwards to redeploy the data files.
- After `--remote`, commit the resulting ref changes in the workspace
  (`git add <layer> && git commit`) if you want to publish them.

### Publishing submodule changes

Submodules check out on a detached HEAD, so switch to a branch (`git checkout main`)
before committing inside a layer. Always push the layer repo *before* pushing the
workspace commit that points at it; otherwise other users' `git pull` fails with
`upload-pack: not our ref <sha>`. The `push.recurseSubmodules=check` setting applied by
the setup scripts enforces this ordering.

---

## Building

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/path/to/install
cmake --build . -j`nproc`                              # all programs
cmake --build . --target propagatorv3 -j`nproc`        # specific program
cmake --install .
```

### Building only part of the stack

Pass `-DCOSMOS_TOP_LAYER=<layer>` to limit which layers are compiled and which
programs are built. Valid values: `kernel` | `micro-agent` | `simulator` | `agent` |
`modules` | `ground-station` (default: `ground-station`).

```bash
cmake .. -DCOSMOS_TOP_LAYER=micro-agent -DCMAKE_INSTALL_PREFIX=/path/to/install
```

Only programs from `kernel` and `micro-agent` will be built; simulator, agent, and
higher programs are skipped.

> Shell on the development machine (viirs) is **tcsh** — use backtick syntax
> (`` `nproc` ``), not `$(nproc)`.

---

## Using COSMOSv5 in an External Project

Add the workspace as a single submodule. Set `COSMOS_SOURCE` to its path and include
the cmake chain file for whichever layer you need. The cmake chain file automatically
initializes any missing lower-layer submodules during configure.

```bash
git submodule add https://github.com/hsfl/cosmosv5.git deps/cosmosv5
git submodule update --init deps/cosmosv5
cd deps/cosmosv5 && ./setup.sh agent && cd ../..
```

```cmake
set(COSMOS_SOURCE "${CMAKE_SOURCE_DIR}/deps/cosmosv5")
set(COSMOS_LIBS pthread)

# Replace "agent" with whichever top layer your project needs.
# The chain builds everything from thirdparty up to that layer automatically.
# Missing lower-layer submodules are auto-initialized during cmake configure.
include(${COSMOS_SOURCE}/agent/cmake/use_cosmos_from_source.cmake)

target_link_libraries(myapp CosmosAgent CosmosSimulator CosmosConvert ...)
```

### Layer reference

| Layer | Include this cmake chain file | Use when you need… |
|---|---|---|
| `kernel` | `kernel/cmake/use_cosmos_from_source.cmake` | math, time, JSON, serial — no network |
| `micro-agent` | `micro-agent/cmake/use_cosmos_from_source.cmake` | networking, file transfer, hardware drivers |
| `simulator` | `simulator/cmake/use_cosmos_from_source.cmake` | orbital mechanics, no agent framework |
| `agent` | `agent/cmake/use_cosmos_from_source.cmake` | full COSMOS: agents, physics, propagation |
| `modules` | `modules/cmake/use_cosmos_from_source.cmake` | pluggable modules (file, websocket, propagator) |
| `ground-station` | `ground-station/cmake/use_cosmos_from_source.cmake` | ground station hardware and agents |

---

## Key cmake behavior

- `COSMOS_SOURCE` must point to the workspace root (the directory containing
  `thirdparty/`, `kernel/`, etc.)
- Each layer's `cmake/use_cosmos_from_source.cmake`:
  - Sets `COSMOS_<LAYER>_INCLUDED TRUE`
  - Auto-initializes the lower-layer submodule if its `CMakeLists.txt` is absent
    (runs `git submodule update --init <lower-layer>` via `execute_process`)
  - Chains to the lower layer's cmake file
- The workspace `CMakeLists.txt` uses `COSMOS_<LAYER>_INCLUDED` flags to
  conditionally add program subdirectories — only initialized layers get programs built
- `CMAKE_INSTALL_PREFIX` is the install root (e.g. `~/cosmos`); binaries go to
  `$prefix/bin/`, resources to `$prefix/resources/`
- Shell on viirs is tcsh — use backtick syntax (`` `nproc` ``), not `$(nproc)`
- **`json11` is bundled in kernel** (`kernel/libraries/json11/`) — MIT license preserved
- **`zlib` is bundled in micro-agent** (`micro-agent/libraries/zlib/`) — zlib license preserved; sets `COSMOS_ZLIB_INCLUDE_DIR` for libpng
- **`thirdparty` provides only `localjpeg` and `localpng`**, included automatically from `modules` and above; `localpng` reads `COSMOS_ZLIB_INCLUDE_DIR` set by micro-agent's chain

---

## Open Issues

| # | Description | Repo |
|---|-------------|------|
| — | `wmm_2025.cof` missing from resources — simulations after 2025-01-01 fail to load the magnetic model | `cosmosv5-resources` |
| #82 | Introduce `timebase.h` to fix `elapsedtime`→`timelib` layering violation | `cosmosv5-kernel` |
| #83 | Merge `configCosmosKernel.h` into `configCosmos.h` | `cosmosv5-kernel` |
| #84 | Replace `cssl_lib` with `serialclass` and eliminate `cssl_lib` | `cosmosv5-micro-agent` |
| #85 | ~~Fold `json11` into kernel; remove `thirdparty` as kernel dependency~~ ✅ | `cosmosv5-kernel` |
| #86 | ~~Fold `zlib` into micro-agent; remove `thirdparty` as micro-agent dependency~~ ✅ | `cosmosv5-micro-agent` |
| #87 | ~~Reduce `thirdparty` to `localjpeg`+`localpng` only; update setup.sh~~ ✅ | `cosmosv5-thirdparty` |
