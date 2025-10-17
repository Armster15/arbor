#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALLED_DIR="$SCRIPT_DIR/installed"

# Create build and installed directories if they don't exist
mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALLED_DIR"

# Change to build directory
cd "$BUILD_DIR"

# configure
../ffmpeg_src/configure --disable-programs --disable-doc --enable-network --enable-shared --disable-static \
    --sysroot="$(xcrun --sdk iphoneos --show-sdk-path)" \
    --enable-cross-compile \
    --arch=arm64 \
    --prefix=../installed \
    --cc="xcrun --sdk iphoneos clang -arch arm64" \
    --cxx="xcrun --sdk iphoneos clang++ -arch arm64" \
    --extra-ldflags="-miphoneos-version-min=16.0" \
    --install-name-dir='@rpath' \
    --disable-audiotoolbox

# build
make -j install
