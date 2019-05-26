#!/bin/bash

set -uex

name=clang-tidy-plugin-support-$TRAVIS_TAG
mkdir -p $name/{include,bin}
cp clang/build/bin/clang-tidy $name/bin
cp clang/tools/extra/clang-tidy/*.h $name/include
cp clang/LICENSE.TXT $name/clang-LICENSE.TXT
tar -cJvf $name.tar.xz $name
