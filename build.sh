#!/bin/bash

set -uex

root=$PWD
date +%s > build-start-time
time_limit=2650

ccache -s

function build_time {
  echo $(($(date +%s) - $(cat $root/build-start-time)))
}

LLVM_VERSION=11

export CC=clang-$LLVM_VERSION
export CXX=clang++-$LLVM_VERSION

llvm_dir=/usr/lib/llvm-$LLVM_VERSION/lib/cmake/llvm

test -f "$llvm_dir/LLVMConfig.cmake"

function git_clone {
  git clone --depth 1 --branch release_80 "$@"
}

git_clone https://github.com/llvm-mirror/clang.git
cd clang/tools
git_clone https://github.com/llvm-mirror/clang-tools-extra.git extra
cd ..

patch -p1 < ../compatibility.patch
patch -p1 < ../plugin-support.patch

mkdir build
cd build
cmake \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DCMAKE_EXE_LINKER_FLAGS="-rdynamic -fuse-ld=lld" \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_TARGETS_TO_BUILD="" \
  -DCLANG_ENABLE_ARCMT=OFF \
  -DLLVM_DIR="$llvm_dir" \
  ..
  # -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
#cat CMakeCache.txt
# Loop over targets so we can abort when aproaching the 50 minute Travis time
# limit
while read targets
do
  time=$(build_time)
  if [ "$time" -gt "$time_limit" ]
  then
    echo "Stopping build; running out of time"
    break
  fi
  make -j3 $targets
done < $root/targets
ccache -s

cd $root
