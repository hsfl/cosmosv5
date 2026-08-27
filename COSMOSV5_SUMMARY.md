# COSMOSv5 Migration Summary

## What was done

The monolithic `cosmos-core` repository was split into seven independently versioned
repositories and migrated to GitHub under the `hsfl` organization. This is the
**COSMOS v5.0** release, the breaking architectural change listed in the cosmos-core
version table.

---

## Final Architecture: Flat Workspace

`hsfl/cosmosv5` is a **flat workspace** — a single repo that holds all 7 layer repos
as top-level git submodules. Users clone one repo and get the full stack.

```
cosmosv5/
  thirdparty/      → hsfl/cosmosv5-thirdparty
  kernel/          → hsfl/cosmosv5-micro-agent
  micro-agent/     → hsfl/cosmosv5-micro-agent
  simulator/       → hsfl/cosmosv5-simulator
  agent/           → hsfl/cosmosv5-agent
  modules/         → hsfl/cosmosv5-modules
  ground-station/  → hsfl/cosmosv5-ground-station
  CMakeLists.txt
```

Each layer repo is independently clonable and buildable. The cmake system requires
`COSMOS_SOURCE` to point at the workspace root (the directory containing all 7
layer subdirectories).

### Architecture decision: flat workspace vs. nested deps

An intermediate approach was tried where each layer repo contained its direct lower
dependency as a nested `deps/` submodule (agent contained simulator, simulator
contained micro-agent, etc.). This produced duplicate checkout trees and was removed.
The flat workspace is simpler: one clone, one `COSMOS_SOURCE`, no duplication.

---

## GitHub Repositories

All repos are public under the `hsfl` organization, on branch `main`.

| Layer | Directory | GitHub Repo |
|------:|-----------|-------------|
| -1 | `thirdparty/` | [hsfl/cosmosv5-thirdparty](https://github.com/hsfl/cosmosv5-thirdparty) |
|  0 | `kernel/` | [hsfl/cosmosv5-kernel](https://github.com/hsfl/cosmosv5-kernel) |
|  1 | `micro-agent/` | [hsfl/cosmosv5-micro-agent](https://github.com/hsfl/cosmosv5-micro-agent) |
|  2 | `simulator/` | [hsfl/cosmosv5-simulator](https://github.com/hsfl/cosmosv5-simulator) |
|  3 | `agent/` | [hsfl/cosmosv5-agent](https://github.com/hsfl/cosmosv5-agent) |
|  4 | `modules/` | [hsfl/cosmosv5-modules](https://github.com/hsfl/cosmosv5-modules) |
|  5 | `ground-station/` | [hsfl/cosmosv5-ground-station](https://github.com/hsfl/cosmosv5-ground-station) |

Landing page: [hsfl/cosmosv5](https://github.com/hsfl/cosmosv5) — README and library
hierarchy doc.

### Local paths

All repos live under `/home2/pilger/cosmos/src/<dir>` with SSH remotes:
`git@github.com:hsfl/cosmosv5-<dir>.git`

---

## Layer Dependency Chain

```
thirdparty → kernel → micro-agent → simulator → agent → modules → ground-station
```

Each layer depends only on the layers below it. The cmake chain is transitive:
including one layer's cmake file builds the full dependency stack below it.

| Layer | Use when you need… |
|-------|-------------------|
| `thirdparty` | json11, zlib, jpeg, png only |
| `kernel` | math, time, JSON, serial — no network |
| `micro-agent` | networking, file transfer, hardware drivers |
| `simulator` | orbital mechanics, no agent framework |
| `agent` | full COSMOS: agents, physics, propagation |
| `modules` | pluggable modules (file, websocket, propagator) |
| `ground-station` | ground station hardware and agents |

---

## Building COSMOSv5

```bash
git clone --recurse-submodules https://github.com/hsfl/cosmosv5.git
cd cosmosv5
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/path/to/install
cmake --build . -j`nproc`                         # all programs
cmake --build . --target propagatorv3 -j`nproc`   # specific program
cmake --install .
```

> Note: shell on the development machine (viirs) is tcsh — use backtick syntax
> (`` `nproc` ``), not `$(nproc)`.

---

## Using COSMOSv5 in an External Project

Add the workspace as a single submodule, point `COSMOS_SOURCE` at it, and include
the cmake chain file for whichever layer you need.

```bash
git submodule add https://github.com/hsfl/cosmosv5.git deps/cosmosv5
git submodule update --init --recursive
```

```cmake
set(COSMOS_SOURCE "${CMAKE_SOURCE_DIR}/deps/cosmosv5")
set(COSMOS_LIBS pthread)

# Replace "agent" with whichever top layer your project needs
include(${COSMOS_SOURCE}/agent/cmake/use_cosmos_from_source.cmake)

target_link_libraries(myapp CosmosAgent CosmosSimulator CosmosConvert ...)
```

---

## CMake System

Each layer exposes `cmake/use_cosmos_from_source.cmake`. The pattern in every file:

1. `get_filename_component(COSMOS_SOURCE_<LAYER> "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)`
   — resolves the layer's own root from wherever the file is included.
2. `if(DEFINED COSMOS_SOURCE)` — chains to the lower layer via `COSMOS_SOURCE`.
3. `FATAL_ERROR` if `COSMOS_SOURCE` is not set.

`COSMOS_SOURCE` must point to the flat workspace root (the directory containing
`thirdparty/`, `kernel/`, etc.).

---

## Key Files

| File | Location | Purpose |
|------|----------|---------|
| `README.md` | `cosmosv5/` repo root | GitHub landing page |
| `cosmos_v5_library_hierarchy.md` | `cosmosv5/` repo root | Full library/target reference |
| `COSMOSV5_WORKSPACE.md` | `cosmos/src/` | Workspace architecture and build instructions |
| `github_migration_plan.md` | `cosmos/src/` | Original migration plan (historical) |
| `COSMOSV5_SUMMARY.md` | `cosmos/src/` | This file |

---

## Open Items

- Tag/semver release strategy: tag each of the 8 repos (`cosmosv5` + 7 layers) at
  a consistent point to allow downstream projects to pin to a release rather than
  a commit hash.
