#!/usr/bin/env bash

set -e

# Download and install GAP
git clone --depth=1 -b stable-4.11 https://github.com/gap-system/gap
cd gap
./autogen.sh
./configure --with-gc=julia --with-julia
make -j4
make bootstrap-pkg-minimal

cd pkg

git clone https://github.com/gap-packages/io
git clone https://github.com/gap-packages/profiling
git clone https://github.com/gap-packages/AutoDoc

$GAPROOT/bin/BuildPackages.sh --with-gaproot=$GAPROOT io profiling
