#!/bin/bash

install_prefix="$HOME/opminstall"
parallel_build_tasks=8

# Clone Trilinos
git clone https://github.com/trilinos/Trilinos.git
cd Trilinos

# Create build directory
mkdir build
cd build

# Configure
cmake .. \
  -D CMAKE_INSTALL_PREFIX=$install_prefix \
  -D TPL_ENABLE_MPI:BOOL=ON \
  -D MPI_BASE_DIR:PATH=/opt/homebrew \
  -D Trilinos_ENABLE_ALL_PACKAGES:BOOL=OFF \
  -D Trilinos_ENABLE_Zoltan:BOOL=ON \

# Build
make -j$parallel_build_tasks
make install
