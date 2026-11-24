#!/bin/zsh
# Compila Core + Tests/main.swift e lo esegue: ./tools/test-core.sh [rules|gemma]
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p build
swiftc -O -swift-version 5 Sources/Core/*.swift Tests/main.swift -o build/test-core
./build/test-core "${1:-rules}"
