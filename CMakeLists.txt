cmake_minimum_required(VERSION 3.20)
project(COSMOSv5)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_BUILD_TYPE Debug)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Workspace root is COSMOS_SOURCE — all layer cmake chain files resolve siblings from here
set(COSMOS_SOURCE "${CMAKE_SOURCE_DIR}" CACHE PATH "COSMOSv5 workspace root")
set(COSMOS_LIBS pthread)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "$ENV{HOME}/cosmos" CACHE PATH "Install prefix" FORCE)
endif()

# Build all libraries via the cmake chain.
# ground-station/cmake/use_cosmos_from_source.cmake chains to modules → agent → simulator
# → micro-agent → kernel → thirdparty automatically.
include(ground-station/cmake/use_cosmos_from_source.cmake)

# Build programs from each layer in dependency order.
# Programs CMakeLists only use already-defined targets — safe to add after the chain.
add_subdirectory(kernel/programs          ${CMAKE_BINARY_DIR}/kernel/programs)
add_subdirectory(micro-agent/programs     ${CMAKE_BINARY_DIR}/micro-agent/programs)
add_subdirectory(simulator/programs       ${CMAKE_BINARY_DIR}/simulator/programs)
add_subdirectory(agent/programs           ${CMAKE_BINARY_DIR}/agent/programs)
add_subdirectory(modules/programs         ${CMAKE_BINARY_DIR}/modules/programs)
add_subdirectory(ground-station/programs  ${CMAKE_BINARY_DIR}/ground-station/programs)
