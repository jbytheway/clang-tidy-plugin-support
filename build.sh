#!/bin/bash

set -uex

root=$PWD
date +%s > build-start-time
if [ "${TRAVIS:-}" = true ]
then
  time_limit=2650
else
  time_limit=36000
fi

ccache --zero-stats
# Increase cache size from default of 500MB because clang is big
ccache --max-size=1G
ccache --show-stats

function build_time {
  echo $(($(date +%s) - $(cat $root/build-start-time)))
}

export CC=clang-$LLVM_VERSION
export CXX=clang++-$LLVM_VERSION

llvm_dir=/usr/lib/llvm-$LLVM_VERSION/lib/cmake/llvm

test -f "$llvm_dir/LLVMConfig.cmake"

git clone --depth 1 --branch release/${LLVM_VERSION}.x \
  https://github.com/llvm/llvm-project.git
cd llvm-project
cd clang/tools
ln -s ../../clang-tools-extra extra
cd ../..

patch -p1 < ../plugin-support.patch

cd clang
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

parallel=$(($(nproc) + 1))

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
  make -j$parallel $targets
done < $root/targets
ccache --show-stats

cd $root
