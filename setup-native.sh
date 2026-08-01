#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# YtMusicSaver native binary setup
#
# Builds:
#   - ffmpeg with MP3/libmp3lame support
#   - Node.js from the official Termux aarch64 package
#   - all required Termux runtime dependencies for Node
#
# Tested OS:
#   CachyOS (Arch-based)
#
# Other operating systems have not been tested.
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/native-build"
OUTPUT_DIR="$SCRIPT_DIR/app/src/main/jniLibs/arm64-v8a"

NDK="${ANDROID_NDK_HOME:-$HOME/AndroidSdkRoot/ndk/28.1.13356709}"
API=24

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
CC="$TOOLCHAIN/bin/aarch64-linux-android${API}-clang"
CXX="$TOOLCHAIN/bin/aarch64-linux-android${API}-clang++"

TERMUX_REPO="https://packages.termux.dev/apt/termux-main"
TERMUX_DIST="stable"
TERMUX_ARCH="aarch64"

NODE_PACKAGE="nodejs-lts"

# Android system libraries. These do NOT need to be bundled.
SYSTEM_LIBS=(
    "libc.so"
    "libm.so"
    "libdl.so"
    "liblog.so"
    "libandroid.so"
    "libcamera2ndk.so"
    "libmediandk.so"
)

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

die() {
    echo
    echo "============================================================"
    echo "ERROR"
    echo "============================================================"
    echo "$1"
    echo
    echo "Fix the problem above and run this script again."
    echo "If the cause is unknown, contact the author."
    exit 1
}

trap 'echo; echo "Build failed at line $LINENO."; echo "See the error above."; exit 1' ERR

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    command_exists "$1" || die "Required command '$1' was not found."
}

echo "============================================================"
echo "YtMusicSaver native binary setup"
echo "============================================================"
echo

# ------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------

echo "[1/9] Checking build dependencies..."

for cmd in \
    git \
    curl \
    wget \
    tar \
    xz \
    unzip \
    make \
    cmake \
    pkg-config \
    python3 \
    patchelf \
    readelf \
    dpkg-deb
do
    require_command "$cmd"
done

[[ -x "$CC" ]] || die "Android NDK compiler not found:

$CC

Set ANDROID_NDK_HOME or install NDK r28b at:
$NDK"

[[ -x "$CXX" ]] || die "Android NDK C++ compiler not found:

$CXX"

echo "OK"
echo

# ------------------------------------------------------------
# Prepare directories
# ------------------------------------------------------------

echo "[2/9] Preparing build directory..."

mkdir -p "$WORK_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$WORK_DIR"

echo "Build directory:"
echo "  $WORK_DIR"
echo

# ------------------------------------------------------------
# Build LAME
# ------------------------------------------------------------

echo "[3/9] Building libmp3lame for Android..."

if [[ ! -d lame ]]; then
    echo "Cloning LAME..."
    git clone --depth 1 https://github.com/lameproject/lame.git
fi

cd "$WORK_DIR/lame"

if [[ -f Makefile ]]; then
    make distclean >/dev/null 2>&1 || true
fi

./configure \
    --host=aarch64-linux-android \
    --build="$(gcc -dumpmachine)" \
    --enable-static \
    --disable-shared \
    --disable-decoder \
    --disable-frontend \
    CC="$CC" \
    AR="$TOOLCHAIN/bin/llvm-ar" \
    RANLIB="$TOOLCHAIN/bin/llvm-ranlib" \
    STRIP="$TOOLCHAIN/bin/llvm-strip"

make -j"$(nproc)"

LAME_PREFIX="$WORK_DIR/lame/install"

rm -rf "$LAME_PREFIX"
mkdir -p "$LAME_PREFIX"

make install \
    DESTDIR="$LAME_PREFIX"

LAME_INCLUDE="$LAME_PREFIX/usr/local/include"
LAME_LIB="$LAME_PREFIX/usr/local/lib"

[[ -f "$LAME_LIB/libmp3lame.a" ]] \
    || die "libmp3lame.a was not produced."

echo "libmp3lame built successfully."
echo

# ------------------------------------------------------------
# Build FFmpeg
# ------------------------------------------------------------

echo "[4/9] Building FFmpeg with MP3/libmp3lame support..."

cd "$WORK_DIR"

if [[ ! -d ffmpeg ]]; then
    echo "Cloning FFmpeg..."
    git clone --depth 1 https://git.ffmpeg.org/ffmpeg.git
fi

cd "$WORK_DIR/ffmpeg"

make distclean >/dev/null 2>&1 || true

PKG_CONFIG_PATH="$LAME_LIB/pkgconfig"

export PKG_CONFIG_PATH

./configure \
    --target-os=android \
    --arch=aarch64 \
    --enable-cross-compile \
    --cross-prefix="$TOOLCHAIN/bin/aarch64-linux-android-" \
    --cc="$CC" \
    --cxx="$CXX" \
    --ar="$TOOLCHAIN/bin/llvm-ar" \
    --ranlib="$TOOLCHAIN/bin/llvm-ranlib" \
    --strip="$TOOLCHAIN/bin/llvm-strip" \
    --sysroot="$TOOLCHAIN/sysroot" \
    --extra-cflags="-I$LAME_INCLUDE" \
    --extra-ldflags="-L$LAME_LIB" \
    --extra-libs="-lm" \
    --disable-shared \
    --enable-static \
    --disable-doc \
    --disable-debug \
    --disable-ffplay \
    --disable-ffprobe \
    --disable-postproc \
    --disable-network \
    --disable-everything \
    --enable-ffmpeg \
    --enable-protocol=file \
    --enable-demuxer=mov \
    --enable-demuxer=mp3 \
    --enable-demuxer=matroska \
    --enable-demuxer=ogg \
    --enable-demuxer=flac \
    --enable-muxer=mp3 \
    --enable-muxer=mp4 \
    --enable-muxer=adts \
    --enable-decoder=aac \
    --enable-decoder=mp3 \
    --enable-decoder=flac \
    --enable-decoder=opus \
    --enable-decoder=vorbis \
    --enable-encoder=libmp3lame \
    --enable-filter=aresample \
    --enable-filter=anull \
    --enable-filter=atrim \
    --enable-filter=asetpts \
    --enable-libmp3lame

make -j"$(nproc)"

FFMPEG="$WORK_DIR/ffmpeg/ffmpeg"

[[ -f "$FFMPEG" ]] || die "FFmpeg binary was not produced."

echo
echo "FFmpeg successfully built."

echo
echo "Checking FFmpeg MP3 encoder..."
"$FFMPEG" -hide_banner -encoders 2>/dev/null \
    | grep -q 'libmp3lame' \
    || die "FFmpeg was built, but libmp3lame encoder is missing."

echo "libmp3lame encoder is present."
echo

# ------------------------------------------------------------
# Download Termux package metadata
# ------------------------------------------------------------

echo "[5/9] Downloading Termux package metadata..."

cd "$WORK_DIR"

PACKAGES_XZ="$WORK_DIR/Packages.xz"
PACKAGES="$WORK_DIR/Packages"

curl -fL \
    "$TERMUX_REPO/dists/$TERMUX_DIST/main/binary-$TERMUX_ARCH/Packages.xz" \
    -o "$PACKAGES_XZ"

xz -dc "$PACKAGES_XZ" > "$PACKAGES"

[[ -s "$PACKAGES" ]] || die "Termux package metadata is empty."

echo "Termux metadata downloaded."
echo

# ------------------------------------------------------------
# Resolve package metadata
# ------------------------------------------------------------

echo "[6/9] Resolving Node.js dependency tree..."

mkdir -p "$WORK_DIR/debs"
mkdir -p "$WORK_DIR/extracted"

declare -A PACKAGE_URLS
declare -A PACKAGE_DEPS
declare -A QUEUED
declare -A DONE

get_package_field() {
    local package="$1"
    local field="$2"

    awk -v pkg="$package" -v wanted="$field" '
        BEGIN {
            RS="";
            FS="\n";
        }

        $0 ~ "^Package: " pkg "$" {
            for (i = 1; i <= NF; i++) {
                if ($i ~ "^" wanted ": ") {
                    sub("^" wanted ": ", "", $i);
                    print $i;
                    exit;
                }
            }
        }
    ' "$PACKAGES"
}

resolve_package() {
    local package="$1"

    [[ -n "${DONE[$package]:-}" ]] && return
    [[ -n "${QUEUED[$package]:-}" ]] && return

    QUEUED["$package"]=1

    local filename
    local depends

    filename="$(get_package_field "$package" "Filename")"

    [[ -n "$filename" ]] \
        || die "Could not find Termux package '$package' in repository metadata."

    PACKAGE_URLS["$package"]="$TERMUX_REPO/$filename"

    depends="$(get_package_field "$package" "Depends" || true)"

    PACKAGE_DEPS["$package"]="$depends"

    # Dependencies can contain:
    #
    #   foo
    #   foo (>= 1.0)
    #   foo:any
    #   foo | bar
    #
    # We only need the first package in alternatives.
    while read -r dep; do
        [[ -z "$dep" ]] && continue

        dep="${dep%%(*}"
        dep="${dep%%:*}"

        # Remove accidental whitespace.
        dep="$(echo "$dep" | xargs)"

        [[ -z "$dep" ]] && continue

        resolve_package "$dep"
    done < <(
        echo "$depends" \
            | tr ',' '\n' \
            | sed 's/|.*//' \
            | sed 's/([^)]*)//g'
    )

    DONE["$package"]=1
}

resolve_package "$NODE_PACKAGE"

echo
echo "Packages required:"
printf '  %s\n' "${!PACKAGE_URLS[@]}"
echo

# ------------------------------------------------------------
# Download and extract packages
# ------------------------------------------------------------

echo "[7/9] Downloading and extracting Termux packages..."

for package in "${!PACKAGE_URLS[@]}"; do
    url="${PACKAGE_URLS[$package]}"
    deb="$WORK_DIR/debs/$package.deb"

    echo
    echo "Downloading $package..."
    echo "  $url"

    curl -fL "$url" -o "$deb"

    [[ -s "$deb" ]] \
        || die "Downloaded package '$package' is empty."

    destination="$WORK_DIR/extracted/$package"

    rm -rf "$destination"
    mkdir -p "$destination"

    dpkg-deb -x "$deb" "$destination"
done

echo
echo "Termux packages extracted."
echo

# ------------------------------------------------------------
# Collect Node and libraries
# ------------------------------------------------------------

echo "[8/9] Collecting Node runtime and libraries..."

NATIVE="$WORK_DIR/native"

rm -rf "$NATIVE"
mkdir -p "$NATIVE"

NODE_FOUND=""

for root in "$WORK_DIR"/extracted/*; do
    [[ -d "$root" ]] || continue

    candidate="$root/data/data/com.termux/files/usr/bin/node"

    if [[ -f "$candidate" ]]; then
        NODE_FOUND="$candidate"
        break
    fi
done

[[ -n "$NODE_FOUND" ]] \
    || die "Could not find the Node executable in extracted Termux packages."

cp "$NODE_FOUND" "$NATIVE/node"

# Collect every shared library from Termux packages.
#
# This deliberately collects all .so files from the dependency packages.
# The final dependency sweep below decides what is actually required.
find "$WORK_DIR"/extracted \
    -type f \
    \( -name '*.so' -o -name '*.so.*' \) \
    -exec cp -n {} "$NATIVE/" \;

echo
echo "Node:"
file "$NATIVE/node"

echo
echo "Initial Node dependencies:"
readelf -d "$NATIVE/node" | grep NEEDED || true
echo

# ------------------------------------------------------------
# Normalize library names
# ------------------------------------------------------------

echo "Normalizing library SONAMEs and dependency references..."

cd "$NATIVE"

declare -A LIB_RENAMES

for file in *.so.*; do
    [[ -f "$file" ]] || continue

    clean="${file%%.so.*}.so"

    # Handle names such as libicudata.so.78.3
    if [[ "$file" =~ ^(lib[^/]+)\.so\.[0-9] ]]; then
        clean="${BASH_REMATCH[1]}.so"
    else
        continue
    fi

    if [[ "$file" != "$clean" ]]; then
        if [[ -e "$clean" ]]; then
            echo "Keeping existing $clean; removing duplicate $file"
            rm -f "$file"
        else
            echo "Renaming $file -> $clean"
            mv "$file" "$clean"
        fi

        LIB_RENAMES["$file"]="$clean"
    fi
done

# Normalize SONAMEs.
for file in *.so; do
    [[ -f "$file" ]] || continue

    if file "$file" | grep -q 'ELF'; then
        patchelf --set-soname "$(basename "$file")" "$file" || true
    fi
done

# Replace references throughout every ELF file.
for file in *; do
    [[ -f "$file" ]] || continue

    file "$file" | grep -q 'ELF' || continue

    needed="$(readelf -d "$file" 2>/dev/null \
        | sed -n 's/.*Shared library: \[\(.*\)\].*/\1/p' \
        || true)"

    while read -r old; do
        [[ -z "$old" ]] && continue

        new="$old"

        if [[ "$old" =~ ^(lib[^/]+)\.so\.[0-9] ]]; then
            new="${BASH_REMATCH[1]}.so"
        fi

        if [[ "$new" != "$old" ]]; then
            if [[ -f "$new" ]]; then
                echo "Patching $file: $old -> $new"
                patchelf --replace-needed "$old" "$new" "$file"
            fi
        fi
    done <<< "$needed"
done

# ------------------------------------------------------------
# Find any remaining missing dependencies
# ------------------------------------------------------------

echo
echo "Checking complete dependency tree..."

missing=0

for file in *; do
    [[ -f "$file" ]] || continue

    file "$file" | grep -q 'ELF' || continue

    while read -r needed; do
        [[ -z "$needed" ]] && continue

        system=0

        for sys in "${SYSTEM_LIBS[@]}"; do
            if [[ "$needed" == "$sys" ]]; then
                system=1
                break
            fi
        done

        [[ "$system" -eq 1 ]] && continue

        if [[ ! -f "$needed" ]]; then
            echo
            echo "MISSING DEPENDENCY:"
            echo "  File:       $file"
            echo "  Needs:      $needed"
            echo
            missing=1
        fi
    done < <(
        readelf -d "$file" 2>/dev/null \
            | sed -n 's/.*Shared library: \[\(.*\)\].*/\1/p'
    )
done

if [[ "$missing" -ne 0 ]]; then
    die "One or more native dependencies are still missing.

The automatic Termux dependency resolver downloaded the package dependency
tree, but the resulting ELF dependency tree still has unresolved libraries."
fi

echo "All native dependencies are present."
echo

# ------------------------------------------------------------
# Final verification
# ------------------------------------------------------------

echo "Final Node dependency list:"
readelf -d node | grep NEEDED || true

echo
echo "Final library dependency lists:"

for file in *.so; do
    [[ -f "$file" ]] || continue

    echo
    echo "== $file =="

    readelf -d "$file" 2>/dev/null \
        | grep NEEDED \
        || true
done

echo

# ------------------------------------------------------------
# Copy output
# ------------------------------------------------------------

echo "[9/9] Installing native binaries..."

rm -f "$OUTPUT_DIR"/*.so

cp "$NATIVE/node" "$OUTPUT_DIR/libnodejs.so"

for file in "$NATIVE"/*.so; do
    [[ -f "$file" ]] || continue
    cp "$file" "$OUTPUT_DIR/"
done

cp "$FFMPEG" "$OUTPUT_DIR/libffmpeg.so"

chmod +x "$OUTPUT_DIR/libnodejs.so"
chmod +x "$OUTPUT_DIR/libffmpeg.so"

echo
echo "============================================================"
echo "SUCCESS"
echo "============================================================"
echo
echo "Native files installed into:"
echo "$OUTPUT_DIR"
echo
ls -lh "$OUTPUT_DIR"
echo

echo "Checking FFmpeg:"
"$OUTPUT_DIR/libffmpeg.so" -hide_banner -version 2>&1 | head -5

echo
echo "Checking MP3 encoder:"
"$OUTPUT_DIR/libffmpeg.so" -hide_banner -encoders 2>/dev/null \
    | grep libmp3lame \
    || die "Final FFmpeg binary does not contain libmp3lame."

echo
echo "Done."