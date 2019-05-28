[![Build Status](https://travis-ci.org/jbytheway/clang-tidy-plugin-support.svg?branch=master)](https://travis-ci.org/jbytheway/clang-tidy-plugin-support)

This repository is an experiment in adding plugin support to clang-tidy.

The intended use case is applying clang-tidy in CI testing of projects, where
you don't want to waste valuable Travis time building clang-tidy every time.

There is an [open issue](https://bugs.llvm.org//show_bug.cgi?id=32739) on
clang-tidy to support plugins, but the response there indicates that the
developers don't believe it to be a feature they are interested in, because of
the API instability.

However, for CI testing it seems reasonable to assume that one could stick to a
specific LLVM version for long enough that API instability is not a serious
concern.

This repository builds against llvm-8 on a Travis Ubuntu Xenial host, with the
intention that it should be usable in Travis on such hosts for other projects.

The logic of the build is contained in [the build script](build.sh).

## How it works

In short, this version of `clang-tidy` is compiled from the usual llvm-8
sources, but with `-rdynamic` enabled, which allows plugins to call functions
within the `clang-tidy` binary.  This is sufficient to enable plugins to be
usable, via `LD_PRELOAD`.  However, that's not always convenient, so I have
also patched in a `-plugins` option that allows you to specify plugins to be
loaded on the command line.

## Configuring a Travis build to use this project

Set up a build with something like the following settings

```yaml
os: linux
dist: xenial
addons: &clang8
  apt:
    packages: ["clang-8", "libclang-8-dev", "llvm-8-dev", "llvm-8-tools"]
    sources: [ubuntu-toolchain-r-test, llvm-toolchain-xenial-8]
```

`libclang-8-dev` and `llvm-8-dev` provide most of the headers a plugin build
will require.  `llvm-8-tools` provides `FileCheck` (actually called
`FileCheck-8` in that package) which is required if you want to write tests for
your plugin in the style of `clang-tidy` tests.

Download and unpack the release tarball from this repository to get the
remaining things required.  It provides:
* Further headers; these are internal `clang-tidy` headers not normally
  installed by llvm.
* The patched `clang-tidy` binary with plugin support.
* A symlink to access `FileCheck` under its usual name, not `FileCheck-8`.
* `check_clang_tidy.py`, also used for tests.

If you are using CMake for your plugin build, you might for example use
something like the following:

```cmake
include(ExternalProject)

find_package(LLVM REQUIRED CONFIG)
find_package(Clang REQUIRED CONFIG)

add_library(YourPlugin MODULE ...)

SET(ctps_version llvm-8.0.1-r12)
SET(ctps_src ${CMAKE_CURRENT_BINARY_DIR}/clang-tidy-plugin-support)

ExternalProject_Add(
    clang-tidy-plugin-support
    URL ${ctps_releases}/${ctps_version}/clang-tidy-plugin-support-${ctps_version}.tar.xz
    URL_HASH SHA256=00ffab0df11250f394830735514c62ae787bd2eb6eb9d5e97471206d270c54e2
    SOURCE_DIR ${ctps_src}
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
    TEST_COMMAND ""
)

add_dependencies(YourPlugin clang-tidy-plugin-support)

target_include_directories(
    YourPlugin SYSTEM PRIVATE
    ${LLVM_INCLUDE_DIRS} ${CLANG_INCLUDE_DIRS} ${ctps_src}/include)

target_compile_definitions(
    YourPlugin PRIVATE ${LLVM_DEFINITIONS})

target_compile_options(
    YourPlugin PRIVATE -fno-exceptions -fno-rtti)
```

When running CMake, it might pick up the llvm 7 headers rather than the llvm 8
headers we need.  If that happens, you can use the following `cmake`
command-line options to direct it to the proper place:
```sh
-DLLVM_DIR=/usr/lib/llvm-8/lib/cmake/llvm
-DClang_DIR=/usr/lib/llvm-8/lib/cmake/clang
```

## Supporting local builds of clang-tidy

If you want to build the plugin on a different platform where you don't have
access to the same Xenial packages and the , then that is also possible.

Check out the llvm sources.  For best compatibility, use the `release_80`
branches within the various repositories at https://llvm.org/git/ or their
mirrors at https://github.com/llvm-mirror.

If you want to add the `-plugins` command-line option, then apply the
[patch](plugin-support.patch) found in this repository.

Build `clang-tidy`, making sure to pass `-DCMAKE_EXE_LINKER_FLAGS="-rdynamic"`
to CMake when configuring your build.

In the CMake code above, add a setting which allows the developer to specify
the location of the necessary `clang-tidy` internal headers.  If that is set,
you can skip downloading the tarball and use the local copy instead.
