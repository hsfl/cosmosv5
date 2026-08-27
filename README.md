# COSMOS Core v5.0

COSMOS Core is the foundational software platform of the COSMOS ecosystem, providing the core
libraries, runtime services, and agent infrastructure required to build and operate distributed
robotic systems, including CubeSats, UAVs, and ground stations.

---

## COSMOS Core v5.0 focuses on:

* A **seven-repository layered architecture** — each layer is independently buildable and
  depends only on the layers below it
* **Agent-based messaging and command/telemetry** — persistent processes with a named request
  interface and UDP-broadcast heartbeat
* **Orbital mechanics and physics simulation** — ephemeris, atmosphere, coordinate transforms,
  spacecraft dynamics
* **Minimal, reusable services** suitable for both embedded flight software and ground systems
* **Automatic dependency delivery** — cloning any layer via `--recurse-submodules` pulls the
  full dependency stack below it

> ⚠️ COSMOS Core v5.0 and its documentation are actively developed.
> If you encounter missing documentation or unexpected behavior, please open an issue.

---

## Who is this for?

* **Flight software developers** integrating COSMOS into embedded or flight systems
* **Ground system developers** building mission operations tools
* **Researchers and students** experimenting with distributed agent systems and orbital simulation

---

## v5.0 Repository Architecture

COSMOS v5.0 replaces the monolithic `core` repository with seven independently versioned
repositories arranged in a strict dependency chain:

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

Each repo includes its direct lower dependency as a git submodule under `deps/`.

---

## Quick Start

### Which layer do you need?

| Goal | Clone this repo |
|------|----------------|
| Write a COSMOS agent or spacecraft program | `cosmosv5-agent` |
| Orbital simulation only (no agent framework) | `cosmosv5-simulator` |
| Lightweight flight software or embedded target | `cosmosv5-micro-agent` |
| Math, time, JSON, serial — no network stack | `cosmosv5-kernel` |
| Ground station software | `cosmosv5-ground-station` |
| Full stack | `cosmosv5-ground-station` |

### Clone and build

Cloning any layer with `--recurse-submodules` automatically delivers all layers below it.

```bash
# Example: agent layer and all its dependencies
git clone --recurse-submodules https://github.com/hsfl/cosmosv5-agent
cd cosmosv5-agent
mkdir build && cd build
cmake ..
cmake --build . -j$(nproc)
```

If you forgot `--recurse-submodules` after cloning:

```bash
git submodule update --init --recursive
```

### Prerequisites

* CMake 3.16+
* A C++17-capable compiler (GCC 9+, Clang 10+)
* For the simulator layer: IERS EOP data, JPL ephemeris files, WMM.COF, DEM tiles
  — see the [Getting Started guide](https://hsfl.github.io/cosmos-docs/pages/2-getting_started/index.html)
  for resource file setup

---

## Documentation

* 📗 [User and Developer Documentation](https://hsfl.github.io/cosmos-docs/)
* 📘 [COSMOS Core API (Doxygen)](https://hsfl.github.io/cosmos-core)
* 📐 [Library Hierarchy & Architecture](cosmos_v5_library_hierarchy.md)

These resources describe:

* Library APIs and CMake target reference
* Agent architecture and message formats
* Build instructions for supported platforms
* Tutorials and example programs

---

## Released Versions

| Version | Mission / Context | Year | Description |
|--------:|------------------|------|-------------|
| **v3.0** | HyTI | 2024 | Significant growth in capabilities driven by thermal infrared mission requirements |
| **v4.1** | Swarm | 2025 | Enhancements supporting multi-node and spacecraft swarm-style operations |
| **v4.2** | Maintenance | Jan 2026 | Major cleanup: repository organization, configuration control, improved onboarding |
| **v4.3** | HyTI-2 | Spring 2026 | Mission-driven updates validated through flight and integrated testing |
| **v5.0** | Architecture split | Fall 2026 | Seven-repository layered architecture; breaking change from monolithic core |

---

## Relevant Links

* [COSMOS Documentation](https://hsfl.github.io/cosmos-docs/)
* [COSMOS Core API (Doxygen)](https://hsfl.github.io/cosmos-core)
* [Getting Started](https://hsfl.github.io/cosmos-docs/pages/2-getting_started/index.html)
* [Hawaii Space Flight Laboratory](https://www.hsfl.hawaii.edu/)
