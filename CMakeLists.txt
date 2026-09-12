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

# COSMOS_TOP_LAYER — highest layer to build from this workspace.
# Only the selected layer and everything below it will be compiled.
# cmake auto-initializes required submodules during configure.
# Resources are not included automatically; initialize with:
#   git submodule update --init resources
set(COSMOS_TOP_LAYER "ground-station" CACHE STRING
    "Highest layer to build (kernel|micro-agent|simulator|agent|modules|ground-station)")
set_property(CACHE COSMOS_TOP_LAYER PROPERTY STRINGS
    kernel micro-agent simulator agent modules ground-station)

# Include the cmake chain for the selected top layer.
# Each chain file automatically includes everything below it.
if(COSMOS_TOP_LAYER STREQUAL "ground-station")
    include(ground-station/cmake/use_cosmos_from_source.cmake)
elseif(COSMOS_TOP_LAYER STREQUAL "modules")
    include(modules/cmake/use_cosmos_from_source.cmake)
elseif(COSMOS_TOP_LAYER STREQUAL "agent")
    include(agent/cmake/use_cosmos_from_source.cmake)
elseif(COSMOS_TOP_LAYER STREQUAL "simulator")
    include(simulator/cmake/use_cosmos_from_source.cmake)
elseif(COSMOS_TOP_LAYER STREQUAL "micro-agent")
    include(micro-agent/cmake/use_cosmos_from_source.cmake)
elseif(COSMOS_TOP_LAYER STREQUAL "kernel")
    include(kernel/cmake/use_cosmos_from_source.cmake)
else()
    message(FATAL_ERROR
        "Unknown COSMOS_TOP_LAYER '${COSMOS_TOP_LAYER}'.\n"
        "Valid values: kernel | micro-agent | simulator | agent | modules | ground-station")
endif()

# Add programs for each layer that was included.
# COSMOS_<LAYER>_INCLUDED is set by each chain file, so only initialized layers are built.
if(COSMOS_KERNEL_INCLUDED)
    add_subdirectory(kernel/programs          ${CMAKE_BINARY_DIR}/kernel/programs)
endif()
if(COSMOS_MICRO_AGENT_INCLUDED)
    add_subdirectory(micro-agent/programs     ${CMAKE_BINARY_DIR}/micro-agent/programs)
endif()
if(COSMOS_SIMULATOR_INCLUDED)
    add_subdirectory(simulator/programs       ${CMAKE_BINARY_DIR}/simulator/programs)
endif()
if(COSMOS_AGENT_INCLUDED)
    add_subdirectory(agent/programs           ${CMAKE_BINARY_DIR}/agent/programs)
endif()
if(COSMOS_MODULES_INCLUDED)
    add_subdirectory(modules/programs         ${CMAKE_BINARY_DIR}/modules/programs)
endif()
if(COSMOS_GROUND_STATION_INCLUDED)
    add_subdirectory(ground-station/programs  ${CMAKE_BINARY_DIR}/ground-station/programs)
endif()

# Install resource files to ${CMAKE_INSTALL_PREFIX}/resources/ if the submodule is present.
if(EXISTS "${CMAKE_SOURCE_DIR}/resources/general")
    install(DIRECTORY resources/general DESTINATION resources)
endif()
