#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
toolchain=$(cd -- "${CLANG_BIN:?Set CLANG_BIN to the Android Clang 17.0.2 bin directory}" && pwd)
output=${OUT_DIR:-"$root/out-r31"}
mkdir -p -- "$output"
output=$(cd -- "$output" && pwd)
cp -- "$root/config.pulse2-r31" "$output/.config"

export PATH="$toolchain:$PATH"
export ARCH=arm64 LLVM=1
export CC="$toolchain/clang" LD="$toolchain/ld.lld" AR="$toolchain/llvm-ar"
export NM="$toolchain/llvm-nm" OBJCOPY="$toolchain/llvm-objcopy"
export OBJDUMP="$toolchain/llvm-objdump" STRIP="$toolchain/llvm-strip"
export HOSTCC="$toolchain/clang" HOSTLD="$toolchain/ld.lld"
export KCFLAGS="-Wno-error=frame-larger-than"
export KBUILD_BUILD_VERSION=31
export KBUILD_BUILD_TIMESTAMP="Wed Nov 25 15:13:16 CST 2026"

make -C "$root/kernel/common" O="$output" olddefconfig
make -C "$root/kernel/common" O="$output" -j"${JOBS:-$(nproc)}" Image
