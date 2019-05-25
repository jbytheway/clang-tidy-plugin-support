#!/bin/bash

set -uex

export CC=clang-8
export CXX=clang++-8

alias git_clone="git clone --depth 1 --branch release_80"

git_clone https://github.com/llvm-mirror/clang.git
cd clang/tools
git_clone https://git.llvm.org/git/clang-tools-extra.git extra
cd ..
mkdir build
cd build
cmake \
  -DCMAKE_EXE_LINKER_FLAGS="-rdynamic" \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_TARGETS_TO_BUILD="" \
  -DCLANG_ENABLE_ARCMT=OFF \
  ..
make -j3
