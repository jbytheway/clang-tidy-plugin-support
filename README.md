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
