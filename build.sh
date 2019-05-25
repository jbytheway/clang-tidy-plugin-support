#!/bin/bash

set -uex

export CC=clang-8
export CXX=clang++-8

llvm_dir=/usr/lib/llvm-8/lib/cmake/llvm

test -f "$llvm_dir/LLVMConfig.cmake"

function git_clone {
  git clone --depth 1 --branch release_80 "$@"
}

git_clone https://github.com/llvm-mirror/clang.git
cd clang/tools
git_clone https://git.llvm.org/git/clang-tools-extra.git extra
cd ..

patch -p1 < ../compatibility.patch
patch -p1 < ../plugin-support.patch
patch -p1 < ../remove-some-checks.patch

mkdir build
cd build
cmake \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_EXE_LINKER_FLAGS="-rdynamic -fuse-ld=lld" \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_TARGETS_TO_BUILD="" \
  -DCLANG_ENABLE_ARCMT=OFF \
  -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DLLVM_DIR="$llvm_dir" \
  ..
cat CMakeCache.txt
ccache -s
make -j3 clang-tidy
ccache -s
