# COSMOS Core v5.0

COSMOS Core is the foundational software platform of the COSMOS ecosystem, providing the core
libraries, runtime services, and agent infrastructure required to build and operate distributed
robotic systems, including CubeSats, UAVs, and ground stations.

---

## v5.0 Repository Architecture

COSMOS v5.0 distributes its code across seven independently versioned repositories arranged in
a strict dependency chain:

```
thirdparty → kernel → micro-agent → simulator → agent → modules → ground-station
```

| Layer | Repository | Purpose |
|------:|-----------|---------|
| -1 | [cosmosv5-thirdparty](https://github.com/hsfl/cosmosv5-thirdparty) | Standalone third-party C/C++ libraries (json11, zlib, jpeg, png) |
|  0 | [cosmosv5-kernel](https://github.com/hsfl/cosmosv5-kernel) | Bare-metal safe primitives: math, time, JSON, packet framing, serial/I2C/disk |
|  1 | [cosmosv5-micro-agent](https://github.com/hsfl/cosmosv5-micro-agent) | Data I/O, networking, file transfer, lightweight hardware drivers |
|  2 | [cosmosv5-simulator](https://github.com/hsfl/cosmosv5-simulator) | Pure orbital mechanics: ephemeris, atmosphere, coordinate math |
|  3 | [cosmosv5-agent](https://github.com/hsfl/cosmosv5-agent) | Full COSMOS namespace, physics simulation, agent framework |
|  4 | [cosmosv5-modules](https://github.com/hsfl/cosmosv5-modules) | Pluggable agent capability modules (file, websocket, packet handler, propagator) |
|  5 | [cosmosv5-ground-station](https://github.com/hsfl/cosmosv5-ground-station) | Ground-station hardware drivers and agents |

This **workspace repository** (`cosmosv5`) contains all seven layers as flat submodules and is
the standard entry point for building and developing COSMOS.

---

## Quick Start

### Clone the workspace

```bash
git clone --recurse-submodules https://github.com/hsfl/cosmosv5.git
cd cosmosv5
```

This delivers all seven layers in a flat directory tree — one checkout each, no duplication.

### Build everything

```bash
mkdir build && cd build
cmake ..
cmake --build . -j$(nproc)
```

### Build up to a specific layer

To build only what you need, target specific libraries or programs:

```bash
mkdir build && cd build
cmake ..
cmake --build . --target CosmosAgent propagatorv3 -j$(nproc)
```

CMake builds only the requested targets and their dependencies — lower layers compile
automatically, upper layers are skipped.

### Prerequisites

* CMake 3.20+
* A C++11-capable compiler (GCC 9+, Clang 10+)
* IERS EOP data, JPL ephemeris files, WMM.COF, and DEM tiles for simulator-layer programs
  — see the [Getting Started guide](https://hsfl.github.io/cosmos-docs/pages/2-getting_started/index.html)

---

## Using COSMOSv5 in an external project

Add the workspace as a single submodule. Your project includes the cmake chain file for
whichever layer it needs — the chain builds all layers below it automatically.

### 1. Add the submodule

```bash
git submodule add https://github.com/hsfl/cosmosv5.git deps/cosmosv5
git submodule update --init --recursive
```

### 2. CMakeLists.txt

```cmake
set(COSMOS_SOURCE "${CMAKE_SOURCE_DIR}/deps/cosmosv5")
set(COSMOS_LIBS pthread)

# Replace "agent" with whichever top layer your project needs.
# The chain builds everything from thirdparty up to that layer automatically.
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
