Put your native binaries here, one per ABI, renamed to lib*.so so Android's
packager installs them into the exec-permitted nativeLibraryDir:

  arm64-v8a/libffmpeg.so    <- static/standalone ffmpeg build for android-arm64
  arm64-v8a/libnodejs.so    <- Bionic-linked Node.js CLI build for android-arm64
  armeabi-v7a/libffmpeg.so  <- same, for 32-bit arm devices
  armeabi-v7a/libnodejs.so

See ../../../../../README.md "Native binaries" for where to get these.
