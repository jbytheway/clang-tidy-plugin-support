#!/bin/bash

set -uex

export CC=clang-8
export CXX=clang++-8

root=$PWD

git clone https://github.com/llvm-mirror/clang.git
cd clang/tools
git clone https://git.llvm.org/git/clang-tools-extra.git extra
cd "$root"
mkdir build
cd build
cmake \
  -DCMAKE_EXE_LINKER_FLAGS="-rdynamic" \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_TARGETS_TO_BUILD="" \
  -DCLANG_ENABLE_ARCMT=OFF \
  ..
make -j3
