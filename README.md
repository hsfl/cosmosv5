# COSMOS Core v5.0

COSMOS Core is the foundational software platform of the COSMOS ecosystem, providing the core
libraries, runtime services, and agent infrastructure required to build and operate distributed
robotic systems, including CubeSats, UAVs, and ground stations.

---

## v5.0 Repository Architecture

COSMOS v5.0 distributes its code across seven independently versioned layer repositories
arranged in a strict dependency chain, plus a resources repository for physics data files:

```
thirdparty → kernel → micro-agent → simulator → agent → modules → ground-station
```

| Layer | Repository | Purpose |
|------:|-----------|---------|
| -1 | [cosmosv5-thirdparty](https://github.com/hsfl/cosmosv5-thirdparty) | Optional upper-layer libraries: localjpeg, localpng (json11 → kernel; zlib → micro-agent) |
|  0 | [cosmosv5-kernel](https://github.com/hsfl/cosmosv5-kernel) | Bare-metal safe primitives: math, time, JSON, packet framing, serial/I2C/disk |
|  1 | [cosmosv5-micro-agent](https://github.com/hsfl/cosmosv5-micro-agent) | Data I/O, networking, file transfer, lightweight hardware drivers |
|  2 | [cosmosv5-simulator](https://github.com/hsfl/cosmosv5-simulator) | Pure orbital mechanics: ephemeris, atmosphere, coordinate math |
|  3 | [cosmosv5-agent](https://github.com/hsfl/cosmosv5-agent) | Full COSMOS namespace, physics simulation, agent framework |
|  4 | [cosmosv5-modules](https://github.com/hsfl/cosmosv5-modules) | Pluggable agent capability modules (file, websocket, packet handler, propagator) |
|  5 | [cosmosv5-ground-station](https://github.com/hsfl/cosmosv5-ground-station) | Ground-station hardware drivers and agents |
| data | [cosmosv5-resources](https://github.com/hsfl/cosmosv5-resources) | Physics data files: gravitational models, JPL ephemeris, IERS data, WMM |

This **workspace repository** (`cosmosv5`) contains all seven layers and the resources repo
as flat submodules and is the standard entry point for building and developing COSMOS.

---

## Quick Start

### Clone the workspace

```bash
git clone https://github.com/hsfl/cosmosv5.git
cd cosmosv5
```

Then initialize only the layers you need:

```bash
./setup.sh agent          # kernel + micro-agent + simulator + agent  [recommended]
./setup.sh micro-agent    # kernel + micro-agent  (no physics/simulation)
./setup.sh ground-station # full stack
./setup.sh all            # full stack + physics resource files (~21 MB extra)
```

On Windows use `setup.bat` instead of `./setup.sh`.

> If you prefer to initialize everything at once:
> `git submodule update --init kernel micro-agent simulator agent`
> Add `thirdparty` if you need modules or ground-station (jpeg/png codecs).
> Add `resources` if you need physics/propagation programs.

### Build and install

```bash
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=~/cosmos
cmake --build . -j`nproc`
cmake --install .
```

Binaries install to `<prefix>/bin/`. The default prefix is `~/cosmos`.

To build only up to a specific layer (skips higher-layer programs and their dependencies):

```bash
cmake .. -DCOSMOS_TOP_LAYER=micro-agent
```

### Prerequisites

* CMake 3.20+
* A C++11-capable compiler (GCC 9+, Clang 10+)
* Git (for submodule auto-initialization during cmake configure)
* Physics/propagation programs additionally require resource files — initialize with `./setup.sh all` or `git -c submodule.resources.update=checkout submodule update --init resources`, then `cmake --install` to deploy them. (The `-c` flag is required because `resources` is marked `update = none` to prevent accidental pulls.)

---

## Keeping Up to Date

The workspace records a specific commit for each layer submodule. Pulling the workspace
updates those recorded commits, but does **not** move your checked-out submodules — you must
sync them yourself.

### Catch up all layer submodules

After pulling the workspace, bring every layer you have checked out to the commit the
workspace records:

```bash
git pull
git submodule update
```

`git submodule update` only touches initialized submodules, so layers you never set up stay
skipped. To add a higher layer later, rerun `./setup.sh <layer>`.

To see where each layer sits relative to the workspace, use `git submodule status` — a leading
`+` means the checked-out commit differs from the one recorded, `-` means not initialized.

> **Developers:** to move every initialized layer to the latest commit on its remote branch
> (rather than the commit the workspace records), use
> `git submodule update --remote`. Commit the resulting ref changes in the workspace
> (`git add <layer> && git commit`) if you want to publish them.

> **Developers — publishing submodule changes:** submodules check out on a detached HEAD,
> so switch to a branch (`git checkout main`) before committing inside a layer. Always push
> the layer repo *before* pushing the workspace commit that points at it; otherwise other
> users' `git pull` fails with `upload-pack: not our ref <sha>`. `setup.sh` / `setup.bat`
> configure git to enforce this; for a clone set up another way, run once in the workspace:
>
> ```bash
> git config push.recurseSubmodules check
> ```
>
> A workspace push is then refused if any submodule commit it references hasn't been pushed.

### Update resources

`resources` is marked `update = none`, so plain `git submodule update` (with or without
`git pull`) silently skips it. Override that setting explicitly:

```bash
# Sync resources to the commit the workspace records
git -c submodule.resources.update=checkout submodule update --init resources

# Or pull the latest resources from the remote
git -c submodule.resources.update=checkout submodule update --remote resources
```

Then redeploy the data files into your install prefix:

```bash
cd build
cmake --install .
```

---

## Using COSMOSv5 in an external project

Add the workspace as a single submodule. Your project includes the cmake chain file for
whichever layer it needs — the chain builds all layers below it automatically.

### 1. Add the submodule

```bash
git submodule add https://github.com/hsfl/cosmosv5.git deps/cosmosv5
git submodule update --init deps/cosmosv5
cd deps/cosmosv5 && ./setup.sh agent && cd ../..
```

### 2. CMakeLists.txt

```cmake
set(COSMOS_SOURCE "${CMAKE_SOURCE_DIR}/deps/cosmosv5")
set(COSMOS_LIBS pthread)

# Replace "agent" with whichever top layer your project needs.
# The chain builds everything from kernel up to that layer automatically.
include(${COSMOS_SOURCE}/agent/cmake/use_cosmos_from_source.cmake)

add_executable(myapp src/main.cpp)
target_link_libraries(myapp CosmosAgent CosmosSimulator CosmosConvert ...)
```

### Layer reference

| If your project needs… | Include this cmake chain file |
|---|---|
| Agent framework, physics, propagation | `agent/cmake/use_cosmos_from_source.cmake` |
| Orbital mechanics only (no agent) | `simulator/cmake/use_cosmos_from_source.cmake` |
| Networking, file transfer, hardware drivers | `micro-agent/cmake/use_cosmos_from_source.cmake` |
| Math, time, JSON, serial only | `kernel/cmake/use_cosmos_from_source.cmake` |
| Pluggable modules (file/websocket/propagator) | `modules/cmake/use_cosmos_from_source.cmake` |
| Ground station hardware | `ground-station/cmake/use_cosmos_from_source.cmake` |

### 3. Updating COSMOSv5

```bash
git submodule update --remote deps/cosmosv5
git add deps/cosmosv5
git commit -m "update cosmosv5 to latest"
```

---

## Documentation

* 📗 [User and Developer Documentation](https://hsfl.github.io/cosmos-docs/)
* 📘 [COSMOS Core API (Doxygen)](https://hsfl.github.io/cosmos-core)
* 📐 [Library Hierarchy & Architecture](cosmos_v5_library_hierarchy.md)
* 🗂️ [Workspace Architecture & Build Reference](COSMOSV5_WORKSPACE.md)
* 📋 [Migration Summary & Change History](COSMOSV5_SUMMARY.md)

---

## Released Versions

| Version | Mission / Context | Year | Description |
|--------:|------------------|------|-------------|
| **v3.0** | HyTI | 2024 | Significant growth in capabilities driven by thermal infrared mission requirements |
| **v4.1** | Swarm | 2025 | Enhancements supporting multi-node and spacecraft swarm-first operations |
| **v4.2** | Maintenance | Jan 2026 | Major cleanup: repository organization, configuration control, improved onboarding |
| **v4.3** | HyTI-2 | Spring 2026 | Mission-driven updates validated through flight and integrated testing |
| **v5.0** | Architecture split | Fall 2026 | Seven-repository layered architecture; breaking change from monolithic core |

---

* [COSMOS Documentation](https://hsfl.github.io/cosmos-docs/)
* [Hawaii Space Flight Laboratory](https://www.hsfl.hawaii.edu/)
