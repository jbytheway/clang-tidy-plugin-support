#!/bin/bash

set -uex

cd llvm-project
name=clang-tidy-plugin-support-$TRAVIS_TAG
mkdir -p $name/{include,bin,lib}
cp clang/build/bin/clang-tidy $name/bin
cp clang/tools/extra/test/clang-tidy/check_clang_tidy.py $name/bin
ln -s /usr/bin/FileCheck-$LLVM_VERSION $name/bin/FileCheck
cp clang/tools/extra/clang-tidy/*.h $name/include
cp clang/LICENSE.TXT $name/clang-LICENSE.TXT
ln -s /usr/include/clang $name/lib/clang
tar -cJvf $name.tar.xz $name
