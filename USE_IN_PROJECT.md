# Using COSMOSv5 in an External Project

## 1. Add cosmosv5 as a submodule

```bash
git submodule add https://github.com/hsfl/cosmosv5.git deps/cosmosv5
git submodule update --init deps/cosmosv5
```

This gives you the workspace repo inside `deps/cosmosv5/`. The layer submodules
are **not** initialized yet — do that in the next step.

## 2. Initialize the layers you need

From inside `deps/cosmosv5/` use the setup script to fetch only the layers your
project depends on:

```bash
cd deps/cosmosv5
./setup.sh agent          # kernel + micro-agent + simulator + agent
cd ../..
```

On Windows use `setup.bat` instead of `./setup.sh`.

Available layer arguments: `kernel` | `micro-agent` | `simulator` | `agent` |
`modules` | `ground-station` | `all` (includes physics resource files, ~21 MB extra)

Alternatively, initialize submodules directly:

```bash
git -C deps/cosmosv5 submodule update --init kernel micro-agent simulator agent
```

> **cmake auto-init:** If you skip this step, the cmake chain file will attempt to
> run `git submodule update --init` for any missing lower-layer dependency at
> configure time — so cmake can handle it automatically as long as git is available.

## 3. In your project CMakeLists.txt

Choose the highest layer you need and include its cmake chain file.
The chain automatically builds all layers below it.

```cmake
# Point to the cosmosv5 workspace
set(COSMOS_SOURCE "${CMAKE_SOURCE_DIR}/deps/cosmosv5")
set(COSMOS_LIBS pthread)

# Include up to the layer you need (chain handles everything below automatically):
#   kernel → micro-agent → simulator → agent → modules (→ thirdparty: jpeg/png) → ground-station
include(${COSMOS_SOURCE}/agent/cmake/use_cosmos_from_source.cmake)

# Link against the targets you need
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

## 4. Physics resource files (optional)

Programs that run physics simulations (e.g. `propagatorv3`) require resource data
files at runtime. These are not part of any layer repo — they live in the separate
`resources/` submodule.

To include them in your project:

```bash
git -C deps/cosmosv5 -c submodule.resources.update=checkout submodule update --init resources
```

Then install them alongside your project's binaries so the runtime can find them.
Programs search for resources via the `COSMOS` or `COSMOSRESOURCES` environment
variable, or the default path `/usr/local/cosmos/resources`.

> **Note:** `wmm_2025.cof` is not yet in the resources repo. Simulations using
> dates after 2025-01-01 will fail to load the magnetic model.

## 5. Update COSMOSv5

```bash
git submodule update --remote deps/cosmosv5
cd deps/cosmosv5 && git submodule update --remote && cd ../..
git add deps/cosmosv5
git commit -m "update cosmosv5 to latest"
```
