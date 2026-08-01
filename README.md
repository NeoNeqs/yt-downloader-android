# YtMusicSaver

Share a video link into this app (from YouTube or anywhere else) and it saves
the audio track into `Music/YtMusicSaver`, visible to any other music app.

## Operating system

Successfully compiled and tested on **CachyOS** (Arch-based Linux).

Other operating systems have **not been tested**.

## Prerequisites

* Android Studio with JDK 17
* Android NDK 28.1.13356709 (NDK r28b)
* A Python 3.12 interpreter available somewhere on your machine, used only
  to run `pip` during the build (separate from the Python that gets
  embedded into the app itself)
* Pre-compiled `ffmpeg` with `libmp3lame` support
* A Bionic-linked Android `node` binary
* Node's runtime dependencies

The native binaries are **not included in this repository** and must be
built/downloaded separately before building the app.

---

## Native binaries

This app runs `ffmpeg` and `node` as real subprocesses rather than
through Android's normal `System.loadLibrary()` mechanism, because yt-dlp
needs to actually fork+exec them (pipe scripts to node, invoke ffmpeg with
CLI args).

Android only allows executing binaries from one specific app directory —
`applicationInfo.nativeLibraryDir` — and the way to get files placed there
is via Gradle's native-library packaging.

For this reason, the executables are deliberately named `lib*.so` even
though they are **executables, not shared libraries**.

The required files for `arm64-v8a` are:

```text
app/src/main/jniLibs/arm64-v8a/
├── libffmpeg.so
├── libnodejs.so
├── libz.so
├── libcares.so
├── libsqlite3.so
├── libcrypto.so
├── libssl.so
├── libicudata.so
├── libicui18n.so
├── libicuuc.so
└── libc++_shared.so
```

### 1. Build ffmpeg

The `ffmpeg` binary must be compiled for Android ARM64 using the Android
NDK and must have `libmp3lame` enabled.

The build has been tested with:

```text
NDK r28b
NDK version: 28.1.13356709
ABI: arm64-v8a
Android API: 24
```

Set the NDK toolchain:

```fish
set -x ANDROID_NDK "$HOME/AndroidSdkRoot/ndk/28.1.13356709"
set -x TOOLCHAIN "$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64"
```

You also need to build/install **LAME** for the Android target first. A
plain FFmpeg NDK build does not provide the MP3 encoder.

Build LAME as a static Android library and make its headers and library
available to FFmpeg. For example, the resulting layout can be:

```text
$HOME/android-libs/lame/
├── include/
│   └── lame/
│       └── lame.h
└── lib/
    └── libmp3lame.a
```

Then configure FFmpeg for Android ARM64:

```bash
./configure \
    --target-os=android \
    --arch=aarch64 \
    --enable-cross-compile \
    --cross-prefix="$TOOLCHAIN/bin/aarch64-linux-android-" \
    --cc="$TOOLCHAIN/bin/aarch64-linux-android24-clang" \
    --cxx="$TOOLCHAIN/bin/aarch64-linux-android24-clang++" \
    --sysroot="$TOOLCHAIN/sysroot" \
    --extra-cflags="-I$HOME/android-libs/lame/include" \
    --extra-ldflags="-L$HOME/android-libs/lame/lib" \
    --disable-shared \
    --enable-static \
    --enable-gpl \
    --enable-libmp3lame \
    --disable-doc \
    --disable-debug \
    --disable-ffplay \
    --disable-ffprobe \
    --enable-ffmpeg
```

Then compile:

```bash
make -j$(nproc)
```

Verify that the resulting binary is an Android ARM64 executable:

```bash
file ffmpeg
```

Expected result should contain something similar to:

```text
ELF 64-bit LSB pie executable, ARM aarch64,
dynamically linked, interpreter /system/bin/linker64,
for Android 24
```

Verify that MP3 encoding is actually present:

```bash
./ffmpeg -hide_banner -encoders | grep mp3
```

You should see:

```text
libmp3lame
```

Also verify the binary's runtime dependencies:

```bash
$TOOLCHAIN/bin/llvm-readelf -d ffmpeg | grep NEEDED
```

The resulting `ffmpeg` binary can then be copied and renamed:

```bash
cp ffmpeg app/src/main/jniLibs/arm64-v8a/libffmpeg.so
```

### 2. Get Node.js for Android

**Do not use a normal Linux Node.js binary.**

A normal Node build for Linux is linked against glibc and will not run on
Android. The Node executable must be compiled against Android's Bionic libc.

Compiling Node.js from source for Android is possible, but is significantly
more complicated because Node builds host-side tools during the process
(`mksnapshot`, `node_js2c`, etc.) while simultaneously cross-compiling the
actual Android executable.

For this project, the recommended approach is to use the **official
Termux `nodejs-lts` package**.

Download the `aarch64` `.deb` package from the official Termux package
repository. The package used during development was:

```text
nodejs-lts
Version: 24.18.0
Architecture: aarch64
```

Extract it:

```bash
mkdir node-termux
dpkg-deb -x nodejs-lts_24.18.0_aarch64.deb node-termux
```

The Node executable will be located at:

```text
node-termux/data/data/com.termux/files/usr/bin/node
```

Verify it is actually an Android/Bionic executable:

```bash
file node-termux/data/data/com.termux/files/usr/bin/node
```

It should report something similar to:

```text
ELF 64-bit LSB shared object, ARM aarch64,
dynamically linked, interpreter /system/bin/linker64,
for Android 24
```

Check its runtime dependencies:

```bash
$TOOLCHAIN/bin/llvm-readelf \
    -d node-termux/data/data/com.termux/files/usr/bin/node \
    | grep NEEDED
```

The Termux Node binary currently requires libraries including:

```text
libz.so.1
libcares.so
libsqlite3.so
libcrypto.so.3
libssl.so.3
libicui18n.so.78
libicuuc.so.78
libc.so
libm.so
libdl.so
libc++_shared.so
```

The Android system provides `libc.so`, `libm.so`, and `libdl.so`, but the
other libraries need to be bundled with the application.

Extract the corresponding runtime libraries from the **same Termux package
repository/version** used for Node:

```text
zlib
c-ares
sqlite
openssl
libicu
libc++
```

Do not mix arbitrary versions from different sources. Node and its libraries
should come from a compatible Termux package set.

#### Verify Node before adding it to the APK

Place the Node executable and its dependencies into a temporary directory:

```text
node-test/
├── node
├── libz.so
├── libcares.so
├── libsqlite3.so
├── libcrypto.so
├── libssl.so
├── libicudata.so
├── libicui18n.so
├── libicuuc.so
└── libc++_shared.so
```

Push the directory to an Android device:

```bash
adb push node-test /data/local/tmp/node-test
```

Then:

```bash
adb shell
cd /data/local/tmp/node-test
chmod +x node
export LD_LIBRARY_PATH=/data/local/tmp/node-test
./node --version
```

A successful result should look like:

```text
v24.18.0
```

Do **not** continue until Node can execute successfully on an actual
Android device.

### 3. Fix library names for Android packaging

Termux libraries normally use versioned names such as:

```text
libssl.so.3
libcrypto.so.3
libicui18n.so.78
libicuuc.so.78
libz.so.1
```

Android's native-library packaging expects files named exactly:

```text
lib<name>.so
```

Rename them to:

```text
libssl.so
libcrypto.so
libicui18n.so
libicuuc.so
libicudata.so
libz.so
```

However, **renaming the file alone is not enough**. ELF binaries may still
refer to the old SONAME.

Use `patchelf` to change both the library's SONAME and any references to
it.

For example:

```bash
patchelf --set-soname libssl.so libssl.so.3
mv libssl.so.3 libssl.so

patchelf --replace-needed libssl.so.3 libssl.so node
```

Do the same for every versioned dependency.

Check every binary recursively:

```bash
for f in node ffmpeg libz.so libcrypto.so libssl.so \
         libicui18n.so libicuuc.so libicudata.so \
         libsqlite3.so libcares.so libc++_shared.so; do
    echo "== $f =="
    readelf -d "$f" | grep NEEDED
done
```

There should be no `.so.1`, `.so.3`, `.so.78`, etc. remaining in the
`NEEDED` entries.

Also check the SONAME of each bundled library:

```bash
readelf -d libssl.so | grep SONAME
readelf -d libcrypto.so | grep SONAME
readelf -d libicuuc.so | grep SONAME
readelf -d libicui18n.so | grep SONAME
```

### 4. Copy the native binaries into the project

Create the directory:

```bash
mkdir -p app/src/main/jniLibs/arm64-v8a
```

Copy the binaries:

```bash
cp node \
   libz.so \
   libcrypto.so \
   libssl.so \
   libicudata.so \
   libicui18n.so \
   libicuuc.so \
   libsqlite3.so \
   libcares.so \
   libc++_shared.so \
   app/src/main/jniLibs/arm64-v8a/
```

Rename Node:

```bash
mv app/src/main/jniLibs/arm64-v8a/node \
   app/src/main/jniLibs/arm64-v8a/libnodejs.so
```

Copy FFmpeg:

```bash
cp ffmpeg app/src/main/jniLibs/arm64-v8a/libffmpeg.so
```

The final directory should contain:

```text
app/src/main/jniLibs/arm64-v8a/
├── libffmpeg.so
├── libnodejs.so
├── libz.so
├── libcares.so
├── libsqlite3.so
├── libcrypto.so
├── libssl.so
├── libicudata.so
├── libicui18n.so
├── libicuuc.so
└── libc++_shared.so
```

### 5. Final native-binary sanity check

Before building the APK, test the exact files that will be packaged:

```bash
adb push app/src/main/jniLibs/arm64-v8a \
    /data/local/tmp/nativetest
```

Then:

```bash
adb shell
cd /data/local/tmp/nativetest

chmod +x libnodejs.so libffmpeg.so

export LD_LIBRARY_PATH=.

./libnodejs.so --version
./libffmpeg.so -version
```

Both commands must execute successfully.

If Node reports a missing `.so`, inspect its dependency tree with:

```bash
readelf -d libnodejs.so | grep NEEDED
```

and then inspect the dependencies themselves:

```bash
readelf -d libssl.so | grep NEEDED
readelf -d libcrypto.so | grep NEEDED
readelf -d libicui18n.so | grep NEEDED
readelf -d libicuuc.so | grep NEEDED
readelf -d libsqlite3.so | grep NEEDED
```

---

## Setup after cloning

### 1. Place the native binaries

Follow the [Native binaries](#native-binaries) section above to build/download
and verify `ffmpeg`, `node`, and all of Node's runtime dependencies.

### 2. Point Chaquopy at your Python 3.12 interpreter

In `app/build.gradle`:

```groovy
chaquopy {
    defaultConfig {
        version "3.12"
        buildPython "/path/to/your/python3.12"
    }
}
```

Find the path with:

```bash
which python3.12
```

or:

```bash
uv python find 3.12
```

or:

```bash
pyenv which python3.12
```

depending on how you installed it.

### 3. Build and install

Always use the project's own Gradle wrapper, not whatever Android Studio
has bundled. The versions are pinned deliberately:

```text
Gradle 8.11.1
AGP 8.9.0
Chaquopy 17.0.0
```

Build and install:

```bash
./gradlew installDebug
```

The first build is slow — Chaquopy downloads a Python distribution and
`pip install`s `yt-dlp[default]` into the app.

### 4. Grant notification permission

Grant the notification permission when prompted on first launch. It is
needed for the "downloading…" progress notification on Android 13+.

---

## Architecture

* **Chaquopy** embeds a real CPython interpreter in the app and runs yt-dlp
  in-process (not as a spawned subprocess), which sidesteps Android 10+'s
  `noexec` restriction on app-writable storage.
* A bundled **ffmpeg** binary does the actual audio extraction/muxing.
* A bundled, **Bionic-compiled Node.js CLI binary** satisfies yt-dlp's
  requirement for an external JS runtime to solve YouTube's signature
  challenge.
* yt-dlp expects to fork+exec a real `node` executable and pass it a script.
  The `nodejs-mobile` library therefore cannot be used for this purpose.
* Both executables live in `app/src/main/jniLibs/<abi>/lib*.so`. Naming them
  `lib*.so` is what makes Gradle package them into
  `applicationInfo.nativeLibraryDir`, the one app directory that is
  exec-permitted.
* `DownloadService` (a foreground service) runs the download off the main
  thread and moves the finished file into `MediaStore.Audio` — no storage
  permission needed on API 29+.
* `UpdateManager` runs a daily `WorkManager` job that re-`pip install --upgrade`s yt-dlp at runtime, so you get fixes for YouTube's frequent
  extractor breakage without shipping a new APK build.

---

## Usage

Share a video link from YouTube (or any app) → choose **YtMusicSaver**
from the share sheet → audio lands in `Music/YtMusicSaver` a few seconds
later, visible to any other music app on the device.

---

## Troubleshooting

If a share fails, check Logcat filtered to the app while reproducing it:

```bash
adb logcat -c
# share the video, wait for it to fail
adb logcat -d | grep -iE "python|yt-dlp|ytmusicsaver|ERROR"
```

`downloader.py`'s exceptions are printed via `traceback.print_exc()`, and
yt-dlp's own progress/errors are tagged `python.stdout` — both show up
here.

### MP3 / encoder not found

MP3 output requires FFmpeg to have been compiled with `libmp3lame` support.

Verify it with:

```bash
./ffmpeg -hide_banner -encoders | grep mp3
```

You should see:

```text
libmp3lame
```

If MP3 fails with `Encoder not found`, rebuild FFmpeg with:

```text
--enable-gpl
--enable-libmp3lame
```

and make sure the Android ARM64 LAME library was available during the
FFmpeg build.

Alternatively, switch `downloader.py`'s `--audio-format` to `"m4a"`.
AAC is built into FFmpeg natively and does not require LAME. If doing this,
update `MediaStoreSaver.kt`'s default MIME type to:

```text
audio/mp4
```

### Node fails to start

If Node reports:

```text
library "libz.so.1" not found
```

or a similar linker error, the bundled runtime dependencies have not been
properly packaged.

Check:

```bash
readelf -d libnodejs.so | grep NEEDED
```

Then check every dependency recursively and make sure all non-system
libraries are present in `jniLibs/arm64-v8a/`.

Remember that simply renaming `libz.so.1` to `libz.so` does not change the
ELF dependency name. Use `patchelf --replace-needed` as described in the
native-binary setup section.

### Android device architecture

The current native binaries target:

```text
arm64-v8a
Android API 24+
```

They therefore require a 64-bit ARM Android device.

The emulator's `x86_64` image requires a separate x86_64 build of both
Node and FFmpeg and is not supported by the supplied native binaries.

---

## Known rough edges to verify before relying on this

* `updater.py`'s pip `--target` path (`UpdateManager.kt`) assumes Chaquopy's
  current on-device package layout
  (`filesDir/chaquopy/AssetFinder/app`). Confirm this against the Chaquopy
  version you actually build with — check Chaquopy's FAQ for "install
  packages at runtime" — this path has changed across Chaquopy releases.
* `--js-runtimes node:<path>` is documented and stable as of yt-dlp
  2025.11.12+ (see the project's EJS documentation), but if you're on an
  older pinned version this flag won't exist yet — the in-app auto-updater
  should keep you current.
* Age-restricted/private videos need cookies; `downloader.py` already
  accepts a `cookies_file` path. Wire up a way to get a `cookies.txt` onto
  the device (e.g. import from a file picker) if this is required.

---

## Two build-config settings

These aren't part of the file-placement step itself, but binaries placed
here won't actually run without them.

In `app/build.gradle`:

```groovy
packaging {
    jniLibs {
        useLegacyPackaging = true
    }
}
```

This forces the files to be extracted to disk at install time instead of
being loaded directly from inside the compressed APK.

Also make sure `AndroidManifest.xml` contains:

```xml
<application
    android:extractNativeLibs="true"
    ...>
```

---

## Chaquopy licensing

Chaquopy is free for open-source / non-commercial apps; commercial
distribution needs a paid license. Check Chaquopy's current licensing terms
before publishing this anywhere.
