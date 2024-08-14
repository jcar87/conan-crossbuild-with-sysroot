# Example 1: cross-building with a sysroot - Find program fails

See issue https://github.com/conan-io/conan/issues/16795

In this directory:

```
docker build . -t conan/crossbuild-examples --platform linux/amd64
docker run --rm -ti conan/crossbuild-examples /bin/bash
```

## Failing example
The following command:

```
conan install --require="zlib/[*]" --build="zlib/*" --profile:host rpi-crossbuild
```

fails with

```
-- Using Conan toolchain: /home/conan/.conan2/p/b/zlib6d714780d6ba5/b/build/Release/generators/conan_toolchain.cmake
-- Conan toolchain: Setting CMAKE_POSITION_INDEPENDENT_CODE=ON (options.fPIC)
-- Conan toolchain: Setting BUILD_SHARED_LIBS = OFF
-- The C compiler identification is GNU 10.5.0
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - failed
-- Check for working C compiler: /opt/cross-pi-gcc-10.5.0-64/bin/aarch64-linux-gnu-gcc
-- Check for working C compiler: /opt/cross-pi-gcc-10.5.0-64/bin/aarch64-linux-gnu-gcc - broken
CMake Error at /usr/share/cmake-3.28/Modules/CMakeTestCCompiler.cmake:67 (message):
  The C compiler

    "/opt/cross-pi-gcc-10.5.0-64/bin/aarch64-linux-gnu-gcc"

  is not able to compile a simple test program.

  It fails with the following output:

    Change Dir: '/home/conan/.conan2/p/b/zlib6d714780d6ba5/b/build/Release/CMakeFiles/CMakeScratch/TryCompile-5SPWyZ'
    
    Run Build Command(s): /usr/bin/cmake -E env VERBOSE=1 /opt/raspberrypi_rootfs/usr/bin/gmake -f Makefile cmTC_d1541/fast
    No such file or directory
    
    

  

  CMake will not be able to correctly generate this project.
Call Stack (most recent call first):
  CMakeLists.txt:4 (project)
```

Because CMake locates the GNU make program at `/opt/raspberrypi_rootfs/usr/bin/gmake`.
The `No such file or directory` comes from the system being unable to find the aarch64 dynamic linker-loader (ld-linux-aarch64.so.1).


## Workaround
Pass a `tools.cmake.cmaketoolchain:user_toolchain` - where the contents set `CMAKE_FIND_ROOT_PATH_MODE_PROGRAM` to `NEVER`.

```
conan install --require="zlib/[*]" --build="zlib/*" --profile:host rpi-crossbuild -c tools.cmake.cmaketoolchain:user_toolchain="['/opt/user_toolchain.cmake']"
```

This will succeed building ZLIB.


# Example 2: Conan's CMakeToolchain does not define required variables when a user_toolchain is provided

When a `user_toolchain` is provided, Conan does *not* define `CMAKE_SYSTEM_NAME`, which causes CMake to _not_ detect cross-compilation, and to incorrectly guess the `CMAKE_SYSTEM_ARCHITECTURE`.

See issue https://github.com/conan-io/conan/issues/16807

To reproduce inside the container:
```
cd /home/conan/examples/cmake-system-info
conan install . --profile:host rpi-crossbuild -c tools.cmake.cmaketoolchain:user_toolchain="['/opt/user_toolchain.cmake']" --build=missing
cmake --preset=conan-release
```

What we get:
```
-- ----------------------------------------------------------
-- CMAKE_SYSTEM_NAME: Linux
-- CMAKE_SYSTEM_PROCESSOR: x86_64
-- CMAKE_CROSSCOMPILING: FALSE
-- ----------------------------------------------------------
```

What we should get:
```
-- ----------------------------------------------------------
-- CMAKE_SYSTEM_NAME: Linux
-- CMAKE_SYSTEM_PROCESSOR: aarch64
-- CMAKE_CROSSCOMPILING: True
-- ----------------------------------------------------------
```

Workaround:
We can try to fix this by defining them via confs, or add them to the profile.

```
rm -rf build
conan install . --profile:host rpi-crossbuild -c tools.cmake.cmaketoolchain:user_toolchain="['/opt/user_toolchain.cmake']" --build=missing -c tools.cmake.cmaketoolchain:system_name="Linux" -c tools.cmake.cmaketoolchain:system_processor="aarch64"
cmake --preset=conan-release
```

Note: defining `CMAKE_SYSTEM_NAME` manually is what causes CMake to set `CMAKE_CROSSCOMPILING` to true.

Proposed fix for https://github.com/conan-io/conan/issues/1680 - if the provided user_toolchain does not define these variables, Conan should guess them.

Note that the behaviour is correct when a user toolchain is *not* provided, however we still need to workaround the `MAKE_FIND_ROOT_PATH_MODE_PROGRAM` issue, e.g.:

```
rm -rf build
conan install . --profile:host rpi-crossbuild  --build=missing -c tools.cmake.cmaketoolchain:system_name="Linux" -c tools.cmake.cmaketoolchain:system_processor="aarch64"
cmake --preset=conan-release -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
```

# Example 3: CMake finds a dependency from the sysroot, when it should pick it up from Conan

```
cd /home/conan/examples/dependency-from-sysroot
conan install . --profile:host rpi-crossbuild -c tools.cmake.cmaketoolchain:user_toolchain="['/opt/user_toolchain.cmake']" --build=missing -c tools.cmake.cmaketoolchain:system_name="Linux" -c tools.cmake.cmaketoolchain:system_processor="aarch64"
cmake --preset conan-release --debug-find-pkg=fmt
cmake --build --preset conan-release
```

We can see that while the build succeeds, it is using the wrong version found inside the sysroot:
```
FMT version found: 7.1.3, expected=11.0.2
FMT was found at: /opt/raspberrypi_rootfs/usr/lib/aarch64-linux-gnu/cmake/fmt
```

The sysroot happens to have a valid installation of `fmt`, but it is an older version than the one we are requiring from Conan.
If we were building natively, the Conan one would be picked up, irrespective of whether the system has a different version installed.

We can "force" CMake to find it by defining `fmt_DIR` to the generators folder, e.g.

```
rm -rf build
conan install . --profile:host rpi-crossbuild -c tools.cmake.cmaketoolchain:user_toolchain="['/opt/user_toolchain.cmake']" --build=missing -c tools.cmake.cmaketoolchain:system_name="Linux" -c tools.cmake.cmaketoolchain:system_processor="aarch64"
cmake --preset conan-release --fresh -DDEFINE_FMT_DIR=ON
cmake --build --preset conan-release
```

we can now see:
```
FMT version found: 11.0.2, expected=11.0.2
FMT was found at: /home/conan/examples/dependency-from-sysroot/build/Release/generators
```

This method may not work for all dependencies.