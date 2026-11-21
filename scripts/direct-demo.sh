#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
demo_build="$(mktemp -d "${TMPDIR:-/tmp}/rehearsal-build.XXXXXX")"
trap 'rm -rf "$demo_build"' EXIT
swiftc -module-cache-path "$demo_build/cache" -parse-as-library -emit-library -emit-module -module-name RehearsalCore \
  Sources/RehearsalCore/*.swift -o "$demo_build/libRehearsalCore.dylib" \
  -emit-module-path "$demo_build/RehearsalCore.swiftmodule"
swiftc -module-cache-path "$demo_build/cache" -parse-as-library -I "$demo_build" -L "$demo_build" -lRehearsalCore \
  -Xlinker -rpath -Xlinker "$demo_build" \
  Sources/RehearsalDemo/main.swift -o "$demo_build/rehearsal-demo"
"$demo_build/rehearsal-demo"
