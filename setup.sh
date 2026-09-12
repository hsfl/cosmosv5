#!/usr/bin/env bash
# Initialize cosmosv5 submodules for a specific layer.
# Usage: ./setup.sh [kernel|micro-agent|simulator|agent|modules|ground-station|all]
# Default: agent
# Use 'all' to also initialize the resources submodule (physics data files, ~21 MB).

set -e

LAYER="${1:-agent}"

case "$LAYER" in
    kernel)          MODULES="kernel" ;;
    micro-agent)     MODULES="kernel micro-agent" ;;
    simulator)       MODULES="kernel micro-agent simulator" ;;
    agent)           MODULES="kernel micro-agent simulator agent" ;;
    modules)         MODULES="thirdparty kernel micro-agent simulator agent modules" ;;
    ground-station)  MODULES="thirdparty kernel micro-agent simulator agent modules ground-station" ;;
    all)             MODULES="thirdparty kernel micro-agent simulator agent modules ground-station resources" ;;
    *)
        echo "Usage: $0 [kernel|micro-agent|simulator|agent|modules|ground-station|all]"
        echo ""
        echo "  kernel          — math, time, JSON, serial (bare-metal safe)"
        echo "  micro-agent     — adds networking, file transfer, hardware drivers"
        echo "  simulator       — adds orbital mechanics (no agent framework)"
        echo "  agent           — full COSMOS: agents, physics, propagation  [default]"
        echo "  modules         — adds pluggable modules (file, websocket, propagator)"
        echo "  ground-station  — adds ground station hardware and agents"
        echo "  all             — everything, including physics resource files (~21 MB extra)"
        exit 1 ;;
esac

echo "Initializing submodules for layer: $LAYER"
# shellcheck disable=SC2086
git submodule update --init $MODULES
echo "Done."
