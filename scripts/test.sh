#!/bin/bash
# Runs the unit tests. Extra arguments go to `swift test`.
#
# With Command Line Tools only, SwiftPM's explicit-module build resolves the macro plugins
# in host/plugins but not Swift Testing's in host/plugins/testing, so every @Test fails with
# "plugin for module 'TestingMacros' not found". Pointing the compiler at it fixes that; with
# Xcode the directory is elsewhere and nothing is added.
set -euo pipefail

plugins="$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
if [[ -d "$plugins" ]]; then
    exec swift test -Xswiftc -plugin-path -Xswiftc "$plugins" "$@"
fi
exec swift test "$@"
