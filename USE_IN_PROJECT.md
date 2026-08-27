# Using COSMOSv5 in an external project

## 1. Add cosmosv5 as a submodule

```bash
git submodule add https://github.com/hsfl/cosmosv5.git deps/cosmosv5
git submodule update --init --recursive
```

This gives you a flat tree of all COSMOSv5 layers inside `deps/cosmosv5/`.

## 2. In your project CMakeLists.txt

Choose the highest layer you need and include its cmake chain file.
The chain automatically builds all layers below it.

```cmake
# Point to the cosmosv5 workspace
set(COSMOS_SOURCE "${CMAKE_SOURCE_DIR}/deps/cosmosv5")
set(COSMOS_LIBS pthread)

# Include up to the layer you need (chain handles everything below automatically):
#   thirdparty → kernel → micro-agent → simulator → agent → modules → ground-station
include(${COSMOS_SOURCE}/agent/cmake/use_cosmos_from_source.cmake)

# Now link against whatever targets you need
target_link_libraries(myapp CosmosAgent CosmosSimulator CosmosConvert ...)
```

## 3. Update COSMOSv5

```bash
git submodule update --remote deps/cosmosv5
git add deps/cosmosv5
git commit -m "update cosmosv5 to latest"
```
