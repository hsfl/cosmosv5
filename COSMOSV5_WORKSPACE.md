# COSMOSv5 Workspace Architecture

## What was built

`hsfl/cosmosv5` is now a **flat workspace** containing all 7 COSMOS layers as git submodules:

```
cosmosv5/
  thirdparty/      → hsfl/cosmosv5-thirdparty
  kernel/          → hsfl/cosmosv5-kernel
  micro-agent/     → hsfl/cosmosv5-micro-agent
  simulator/       → hsfl/cosmosv5-simulator
  agent/           → hsfl/cosmosv5-agent
  modules/         → hsfl/cosmosv5-modules
  ground-station/  → hsfl/cosmosv5-ground-station
  CMakeLists.txt
```

## What changed from the previous approach

Previously each layer repo contained its dependency as a nested `deps/` submodule (agent
contained simulator, simulator contained micro-agent, etc.), producing duplicate checkout
trees. That has been removed. Each layer repo's cmake now requires `COSMOS_SOURCE` to be
set pointing at the workspace root.

## Building COSMOSv5

```bash
git clone --recurse-submodules https://github.com/hsfl/cosmosv5.git
cd cosmosv5
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/path/to/install
cmake --build . -j`nproc`                              # all programs
cmake --build . --target propagatorv3 -j`nproc`        # specific program
cmake --install .
```

## Using COSMOSv5 in an external project

Add the workspace as a single submodule. Set `COSMOS_SOURCE` to its path and include the
cmake chain file for whichever layer you need — the chain builds all layers below it
automatically.

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

## Layer reference

| Layer          | Use when you need…                             |
|----------------|------------------------------------------------|
| `thirdparty`   | json11, zlib, jpeg, png only                   |
| `kernel`       | math, time, JSON, serial — no network          |
| `micro-agent`  | networking, file transfer, hardware drivers    |
| `simulator`    | orbital mechanics, no agent framework          |
| `agent`        | full COSMOS: agents, physics, propagation      |
| `modules`      | pluggable modules (file, websocket, propagator)|
| `ground-station` | ground station hardware and agents           |

## Key cmake behavior

- `COSMOS_SOURCE` must point to the workspace root (the directory containing `thirdparty/`,
  `kernel/`, etc.)
- Each layer's `cmake/use_cosmos_from_source.cmake` chains to the layer below it — including
  one layer's file is sufficient to build the entire dependency stack below it
- Shell is tcsh on this machine — use backtick syntax (`` `nproc` ``), not `$(nproc)`
