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

This repository builds against LLVM 12 on a Travis Ubuntu Focal host, with the
intention that it should be usable in Travis on such hosts for other projects.

For a version using LLVM 8 on Ubuntu Xenial, see the [llvm-8
branch](https://github.com/jbytheway/clang-tidy-plugin-support/tree/llvm-8).

The logic of the build is contained in [the build script](build.sh).

This project was created for the benefit of
[Cataclysm-DDA](https://github.com/CleverRaven/Cataclysm-DDA) (though my
intention is that it should be applicable to any project with a desire for
custom clang-tidy checks).  If you'd like to see more details about how it's
used there you can skip down to the [discussion below](#real-world-example).

## How it works

Plugin support is implemented in two different ways in this repository.

### Plugin support in the `clang-tidy` executable

In short, this version of `clang-tidy` is compiled from the usual llvm-12
sources, but with `-rdynamic` enabled, which allows plugins to call functions
within the `clang-tidy` binary.  This is sufficient to enable plugins to be
usable, via `LD_PRELOAD`.  However, that's not always convenient, so I have
also patched in a `-plugins` option that allows you to specify plugins to be
loaded on the command line.

### `clang-tidy` as a static library
The LLVM sources allow building a static library `lib/clangTidyMain.a`
which contains the usual functionality of `clang-tidy`, excluding
the main function.  Therefore you can easily switch from building your
plugin as a dynamic library to linking your plugin against `clangTidyMain.a`
to create a custom `clang-tidy` executable.  `check_clang_tidy.py` is patched
in this repository to allow using it with the custom `clang-tidy` executable.

## Configuring a Travis build to use this project

Set up a build with something like the following settings

```yaml
os: linux
dist: xenial
addons: &clang12
  apt:
    sources:
      - sourceline: ppa:ubuntu-toolchain-r/test
      - sourceline: 'deb http://apt.llvm.org/focal/ llvm-toolchain-focal-12 main'
        key_url: https://apt.llvm.org/llvm-snapshot.gpg.key
    packages: ["clang-12", "libclang-12-dev", "llvm-12-dev", "llvm-12-tools"]
```

`libclang-12-dev` and `llvm-12-dev` provide most of the headers a plugin build
will require.  `llvm-12-tools` provides `FileCheck` (actually called
`FileCheck-12` in that package) which is required if you want to write tests for
your plugin in the style of `clang-tidy` tests.

Download and unpack the release tarball from this repository to get the
remaining things required.  It provides:
* Further headers; these are internal `clang-tidy` headers not normally
  installed by llvm.
* The patched `clang-tidy` binary with plugin support.
* A static library `clangTidyMain.a` containing the usual `clang-tidy`
  functionality, excluding the main function.
* A symlink to access `FileCheck` under its usual name, not `FileCheck-12`.
* `check_clang_tidy.py`, also used for tests.

If you are using CMake for your plugin build, you might for example use
something like the following:

```cmake
include(ExternalProject)

find_package(LLVM REQUIRED CONFIG)
find_package(Clang REQUIRED CONFIG)

add_library(YourPlugin MODULE ...)
# or `add_executable(YourExecutable ...)` if you want to build a custom executable

SET(ctps_version llvm-12.0.0-r1)
SET(ctps_src ${CMAKE_CURRENT_BINARY_DIR}/clang-tidy-plugin-support)

ExternalProject_Add(
    clang-tidy-plugin-support
    URL ${ctps_releases}/${ctps_version}/clang-tidy-plugin-support-${ctps_version}.tar.xz
    URL_HASH SHA256=40626a0cb132b6eb137c4c7b5b1a04a0c96623c076790b848cc577b95a8889c5
    SOURCE_DIR ${ctps_src}
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
    TEST_COMMAND ""
)

add_dependencies(YourPlugin clang-tidy-plugin-support)

#### These are needed if you want to build a custom executable
# target_link_libraries(
#     YourExecutable
#     clangTidyMain
#     )

target_include_directories(
    YourPlugin SYSTEM PRIVATE
    ${LLVM_INCLUDE_DIRS} ${CLANG_INCLUDE_DIRS} ${ctps_src}/include)

target_compile_definitions(
    YourPlugin PRIVATE ${LLVM_DEFINITIONS})

target_compile_options(
    YourPlugin PRIVATE -fno-exceptions -fno-rtti)
```

When building a custom executable, the main function should be implemented and
call `clang::tidy::clangTidyMain( argc, argv )` declared in
`clang-tools-extra/clang-tidy/tool/ClangTidyMain.h` within the LLVM sources.

When running CMake, it might pick up the system llvm headers rather than the
headers we need.  If that happens, you can use the following `cmake`
command-line options to direct it to the proper place:
```sh
-DLLVM_DIR=/usr/lib/llvm-12/lib/cmake/llvm
-DClang_DIR=/usr/lib/llvm-12/lib/cmake/clang
```

## Supporting local builds of clang-tidy

If you want to build the plugin on a different platform where you don't have
access to the same Focal packages and the precompiled version will not work,
then that is also possible.

Check out the llvm sources.  For best compatibility, use the `release/12.x`
branches within the official LLVM repo at
https://github.com/llvm/llvm-project.git.

If you want to add the `-plugins` command-line option or build a custom
executable, apply the [patch](plugin-support.patch) found in this repository.

If you want to run the `check_clang_tidy.py` script with the custom clang-tidy
executable or run the `run-clang-tidy.py` script to automatically apply
clang-tidy suggestions, apply the [scripts patch](clang-tidy-scripts.patch)
found in this repository and add the respective command line options when
running the scripts.

Build `clang-tidy`. If you intend to run `clang-tidy` with the dynamic plugin
support, make sure to pass `-DCMAKE_EXE_LINKER_FLAGS="-rdynamic"` to CMake
when configuring your build.

In the CMake code above, add a setting which allows the developer to specify
the location of the necessary `clang-tidy` internal headers.  If that is set,
you can skip downloading the tarball and use the local copy instead.

## Real-world example

This project is used in the CI of
[Cataclysm-DDA](https://github.com/CleverRaven/Cataclysm-DDA).  Here are some
pointers to the relevant pieces of the codebase.

In `.travis.yml` the [relevant
job](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/.travis.yml#L122-L128)
uses the LLVM toolchain repo (via `addons` `apt` `sources`) and installs
`libclang-8-dev`, `llvm-8-dev`, and `llvm-8-tools`.  It also sets
`CATA_CLANG_TIDY=plugin`, which will be referenced later.

In this case the build setup script `requirements.sh` [installs
lit](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/build-scripts/requirements.sh#L32-L34),
which is used for the plugin tests.

The build script `build.sh` [sets up the relevant cmake
options](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/build-scripts/build.sh#L49-L56),
[tests the
plugin](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/build-scripts/build.sh#L70-L83)
(if it was built), and [runs
`clang-tidy`](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/build-scripts/build.sh#L85-L125).
Note that most of the logic here relates to choosing a good random susbet of
the source code to run `clang-tidy` on, because the Travis-imposed limit of 50
minutes is insufficient time for a full `clang-tidy` run.

This top-level `CMakeLists.txt` [conditionally
builds](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/CMakeLists.txt#L349-L351)
the plugin code.

The plugin's `CMakeLists.txt` [finds LLVM and
clang](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/tools/clang-tidy-plugin/CMakeLists.txt#L3-L4)
in the usual CMake way (using `find_package`).  However, for the patched
`clang-tidy` it either [uses
`ExternalProject_Add`](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/tools/clang-tidy-plugin/CMakeLists.txt#L24-L43)
to download from this project or [a user-specified
version](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/tools/clang-tidy-plugin/CMakeLists.txt#L45-L46)
to support local builds on other platforms.  It also [provides lit
options](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/tools/clang-tidy-plugin/CMakeLists.txt#L62)
for the plugin tests.

The tests use `lit`, similarly to other clang-tidy checks.  Here is [one
example](https://github.com/CleverRaven/Cataclysm-DDA/blob/146de609cd023dfef63db7913d4180a861343e9d/tools/clang-tidy-plugin/test/no-long.cpp#L1)
