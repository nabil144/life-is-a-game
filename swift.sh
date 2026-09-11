#!/usr/bin/env bash
# Run the project-local Swift toolchain on this Arch laptop.
# The Ubuntu toolchain needs libncurses.so.6 and libxml2.so.2, which Arch does not ship under those names.
# .toolchain/shim/ carries them (an ncurses symlink plus libxml2 and libicu74 from Ubuntu) so nothing touches the system.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tc="$here/.toolchain/swift-6.2.4-RELEASE-ubuntu24.04/usr"
export LD_LIBRARY_PATH="$here/.toolchain/shim${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$tc/bin:$PATH"
exec "$tc/bin/swift" "$@"
